#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ostruct'
require 'optparse'
require 'pathname'
require 'find'
require 'fileutils'
require 'data_mapper'

require_relative 'andyrb/mood'
require_relative 'andyrb/util/hashfile'
require_relative 'andyrb/core/cleanup'
require_relative 'andyrb/videoinfo/database'
require_relative 'andyrb/videoinfo/genhash'
require_relative 'andyrb/videoinfo/filelist'
require_relative 'andyrb/options'

Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include

opts = Options.new(ARGV.dup.cleanup) do |defaults|
  defaults[:db] = Pathname.getwd.join('videoinfo.sqlite')
  defaults[:debug] = false
  defaults[:verbose] = false
  defaults[:maintainence] = false
  defaults[:regen] = false
  defaults[:reset_json] = false
  defaults[:reset_all] = false
end
def opts.files
  out = @source.dup
  out = out.nil? || out.empty? ? [] : out
  out.keep_if { |f| File.file?(f) } unless nil? || empty?
  out.freeze
end
opts.construct! do |h, i|
  h.on('--database [file]', String, 'Location where the database will be written') { |d| i[:db] = d }
  h.on('-d', '--debug', "Don't actually do anything, just print what would be done.") do
    i[:debug] = true
    i[:verbose] = true
  end
  h.on('-r', '--regen', 'Drops and recreates the videoinfo table (used for schema changes, testing, etc.)') { i[:regen] = true }
  h.on('--reset-json', 'Drops and recreates the videojson table.') { i[:reset_json] = true }
  h.on('--reset-all', 'Drops and recreates both the videoinfo and videojson tables.') { i[:reset_all] = true }
  h.on('-v', '--verbose', 'Activates verbose mode') { i[:verbose] = true }
  h.on('-m', '--mantainence', 'Vacuum the database.') { i[:maintainence] = true }
end
files = opts.files

if files.nil? || files.empty?
  wdpath = Pathname.getwd.find.to_a
  puts wdpath if Args.debug
  wdpath.keep_if(&:file?)
  files = wdpath.map(&:to_s)
  puts files if Args.debug
end

case
when Args.debug
  puts Args.inspect
  puts files.inspect
end

FileUtils.touch(Args.db.basename.to_s) unless Args.db.file?
DataMapper::Model.raise_on_save_failure = true
DataMapper.setup(:default, "sqlite:#{Args.db.realpath}")
DataMapper::Logger.new($stdout, :debug) if [Args.debug, Args.verbose].any?
db = DataMapper.repository(:default).adapter
gvi = VideoInfo::Database::Data.new(Args.db.realpath, Args.verbose)
DataMapper.finalize
begin
  DataMapper.auto_upgrade! unless Args.reset_all
rescue DataObjects::SyntaxError
  DataMapper.auto_migrate!
end
DataMapper.auto_migrate! if Args.reset_all

if Args.regen && !Args.reset_all
  puts Mood.neutral('Resetting videoinfo table')
  begin
    VideoInfo::Database::Videoinfo.auto_upgrade! # avoid not null errors
    VideoInfo::Database::Videoinfo.all.destroy
  rescue DataObjects::SyntaxError
    VideoInfo::Database::Videoinfo.auto_migrate!
  end

  DataMapper.auto_upgrade!
  db.execute('vacuum')
end

if [Args.reset_json, !Args.reset_all].all?
  puts Mood.neutral('Resetting JSON Cache')
  VideoInfo::Database::Videojson.all.destroy
  # db.execute('drop table if exists videojson')
  begin
    VideoInfo::Database::Videojson.auto_upgrade!
  rescue DataObjects::SyntaxError
    VideoInfo::Database::Videojson.auto_migrate!
  end
  db.execute('vacuum')
  exit
end

if Args.maintainence
  puts Mood.neutral('Vacuuming Database.')
  db.execute('vacuum')
  exit
end

initlist = []

if defined?(files) && files && files.is_a?(Array) && !files.empty?
  initlist = files.map do |i|
    path = Pathname.new(i).freeze
    dir = nil
    if path.directory?
      dir = path.find.to_a
      dir.keep_if(&:file?)
      dir.map!(&:to_s)
    end
    dir unless path.file?
    path.realpath.to_s if path.file?
  end
end

initlist.cleanup!.freeze

existing = gvi.existing
existing.map!(&:filename) if existing.is_a?(Array)
existing.freeze unless frozen?

# print "#{existing}\n"
filelist = VideoInfo.genfilelist(initlist, testmode: Args.debug)
filelist.delete_if { |h| existing.include?(File.basename(h.to_s)) } unless existing.nil? || existing.empty?
filelist.freeze unless frozen?

case
when Args.debug
  puts 'Initial list:'
  # print "#{initlist}\n"
  puts initlist.inspect
  puts 'Existing hash list:'
  # print "#{existing}\n"
  puts existing.inspect
  puts 'File list:'
  # print "#{filelist}\n"
  puts filelist.inspect
  exit
end

case
when filelist.empty?
  puts(Mood.happy { 'All files already in the database or there are no media files.' })
  exit
end

digests = Util.hashfile(filelist).freeze

case
when Args.debug
  print "#{digests}\n"
  print "#{filelist}\n"
end

filelist.each do |file|
  insert = VideoInfo::Database::Videoinfo.new
  jsondata = gvi.json(file).freeze
  case
  when Args.debug
    print "#{digests[file]}\n"
    print "#{file}\n"
  when !Args.debug
    VideoInfo.genhash(file, jsondata, digests) do |h|
      begin
        puts(Mood.happy { "Writing metadata for #{File.basename(file)}" })
        insert.attributes = h
        insert.save
      rescue DataMapper::SaveFailureError
        insert.errors.each { |e| puts e } if Args.verbose
      end
    end
  end
  print "#{VideoInfo.genhash(file, jsondata, digests)}\n" if Args.debug
end
