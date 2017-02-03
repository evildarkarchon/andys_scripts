#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'find'
require 'fileutils'
require 'data_mapper'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.db = Pathname.getwd + 'videoinfo.sqlite'
    options.debug = false
    options.verbose = false

    optparse = OptionParser.new do |opts|
      opts.on('--database file', 'Location where the database will be written') { |d| options.db = Pathname.new(d) }
      opts.on('-d', '--debug', "Don't actually do anything, just print what would be done.") do
        options.debug = true
        options.verbose = true
      end
      opts.on('-m', '--maintainence', 'Performs simple maintainence operations on the database.') { options.m = true }
      opts.on('-r', '--regen', 'Drops and recreates the videoinfo table (used for schema changes, testing, etc.)') { options.regen = true }
      opts.on('--reset-json', 'Drops and recreates the videojson table.') { options.reset_json = true }
      opts.on('--reset-all', 'Drops and recreates both the videoinfo and videojson tables.') { options.reset_all = true }
      opts.on('-v', '--verbose', 'Activates Verbose Mode') { options.verbose = true }
    end
    optparse.parse!(args)
    options
  end
end
Args = Options.parse(ARGV)
Args.files = ARGV unless ARGV.nil? || ARGV.empty?
Args.files.flatten! if ARGV.respond_to?(:flatten!)
Args.files.compact! if ARGV.respond_to?(:compact!)
Args.files.uniq! if ARGV.respond_to?(:uniq!)
Args.files.keep_if { |filename| File.file?(filename) } unless Args.files.nil? || Args.files.empty?

case
when Args.files.empty?
  Find.find(Dir.getwd) do |path|
    Find.prune if File.basename(path)[0].include?('.') # Don't look any further into this directory.
    file = File.file?(path)
    next unless file
    puts path if Args.debug
    Args.files << path if file
  end
end

case
when Args.debug
  # puts Args
  # puts Args.files
  print "#{Args}\n"
  print "#{Args.files}\n"
end

FileUtils.touch(Args.db.basename.to_s) unless Args.db.file?
DataMapper::Model.raise_on_save_failure = true
DataMapper.setup(:default, "sqlite:#{Args.db.realpath}")
DataMapper::Logger.new($stdout, :debug) if Args.debug || Args.verbose
db = DataMapper.repository(:default).adapter
# vi = GenerateVideoInfo::Videoinfo.new
# print "#{vi.inspect}\n"
gvi = GenerateVideoInfo::Data.new(Args.db.realpath, Args.verbose)
DataMapper.finalize
begin
  DataMapper.auto_upgrade! unless Args.reset_all
rescue DataObjects::SyntaxError
  DataMapper.auto_migrate!
end
DataMapper.auto_migrate! if Args.reset_all

case
when Args.regen && !Args.reset_all
  puts Mood.neutral('Resetting videoinfo table')
  begin
    GenerateVideoInfo::Videoinfo.auto_upgrade! # avoid not null errors
    GenerateVideoInfo::Videoinfo.all.destroy
  rescue DataObjects::SyntaxError
    GenerateVideoInfo::Videoinfo.auto_migrate!
  end
  # db.execute('drop table if exists videoinfo')
  DataMapper.auto_upgrade!
  db.execute('vacuum')
end

case
when Args.reset_json && !Args.reset_all
  puts Mood.neutral('Resetting JSON Cache')
  GenerateVideoInfo::Videojson.all.destroy
  # db.execute('drop table if exists videojson')
  begin
    GenerateVideoInfo::Videojson.auto_upgrade!
  rescue DataObjects::SyntaxError
    GenerateVideoInfo::Videojson.auto_migrate!
  end
  db.execute('vacuum')
  exit
end

if Args.maintainence
  db.execute('vacuum')
  exit
end

initlist = []

case
when Args.files && Args.files.is_a?(Array)
  Args.files.each do |entry|
    path = Pathname.new(entry).realpath
    initlist << path.to_s if path.file?
    # if path.directory? # rubocop:disable Style/Next
    #   Find.find(path) do |direntry|
    #     if File.basename(entry)[0].include?('.')
    #       Find.prune # Don't look any further into this directory.
    #     else
    #       initlist << direntry.to_s if File.file? direntry # rubocop:disable Metrics/BlockNesting
    #       next
    #    end
    #   end
    # end
    dir =
      case
      when path.directory?
        dir = path.find do |i|
          Find.prune if i.basename[0].include?('.')
        end
        dir = dir.to_a
        dir.keep_if(&:file?)
        dir.each { |d| initlist << d.to_s }
      end
  end
end

initlist.flatten!
initlist.uniq!

existing = {}
existing = gvi.existing
# print "#{existing}\n"
filelist = GenerateVideoInfo.genfilelist(initlist, Args.debug)
filelist.delete_if { |h| existing.each { |e| h.in? e[:filename] } } unless existing.nil? || existing.empty?

case
when Args.debug
  puts 'Initial list:'
  print initlist
  print "\n"
  puts 'Existing hash list:'
  print existing
  print "\n"
  puts 'File list:'
  print filelist
  print "\n"
  exit
end

case
when filelist.empty?
  puts Mood.happy { 'All files already in the database or there are no media files.' }
  exit
end

digests = Util.hashfile(filelist)

case
when Args.debug
  print "#{digests}\n"
  print "#{filelist}\n"
end

filelist.each do |file|
  insert = GenerateVideoInfo::Videoinfo.new
  jsondata = gvi.json(file)
  case
  when Args.debug
    print "#{digests[file]}\n"
    print "#{file}\n"
  when !Args.debug
    GenerateVideoInfo.genhash(file, jsondata, digests) do |h|
      begin
        puts Mood.happy("Writing metadata for #{File.basename(file)}")
        insert.attributes = h
        insert.save
      rescue DataMapper::SaveFailureError
        insert.errors.each { |e| puts e } if Args.verbose
      end
    end
  end
  print "#{GenerateVideoInfo.genhash(file, jsondata, digests)}\n" if Args.debug
end
