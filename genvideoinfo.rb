#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'find'
require 'fileutils'
require 'data_mapper'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo_dm'

# rubocop:disable Style/Semicolon
class Options
  def self.parse(args)
    options = OpenStruct.new
    options.db = Pathname.new('./videoinfo.sqlite')
    options.debug = false
    options.verbose = false

    optparse = OptionParser.new do |opts|
      opts.on('--database file', 'Location where the database will be written') { |d| options.db = Pathname.new(d) }
      opts.on('-d', '--debug', "Don't actually do anything, just print what would be done.") { |d| options.debug = d; options.verbose = d }
      opts.on('-m', '--maintainence', 'Performs simple maintainence operations on the database.') { |m| options.m = m }
      opts.on('-r', '--regen', 'Drops and recreates the videoinfo table (used for schema changes, testing, etc.)') { |r| options.regen = r }
      opts.on('--reset-json', 'Drops and recreates the videojson table.') { |r| options.reset_json = r }
      opts.on('--reset-all', 'Drops and recreates both the videoinfo and videojson tables.') { |r| options.reset_all = r }
      opts.on('-v', '--verbose', 'Activates Verbose Mode') { |v| options.verbose = v }
    end
    optparse.parse!(args)
    options
  end
end
options = Options.parse(ARGV)
options.files = []
options.files = ARGV unless ARGV.nil? || ARGV.empty?
case
when options.files.empty?
  Find.find(Dir.getwd) do |path|
    if File.basename(path)[0] == ?. # rubocop:disable Style/CharacterLiteral
      Find.prune # Don't look any further into this directory.
    else
      puts path if options.debug
      options.files << path
      next
    end
  end
end
case
when options.debug
  puts options
  puts options.files
end
FileUtils.touch(options.db.basename.to_s) unless options.db.file?
DataMapper::Model.raise_on_save_failure = true
DataMapper.setup(:default, "sqlite:#{options.db.realpath}")
DataMapper::Logger.new($stdout, :debug) if options.debug || options.verbose
db = DataMapper.repository(:default).adapter
# vi = GenerateVideoInfo::Videoinfo.new
# print "#{vi.inspect}\n"
gvi = GenerateVideoInfo::Data.new(options.db.realpath, options.verbose)
DataMapper.finalize
begin
  DataMapper.auto_upgrade! unless options.reset_all
rescue DataObjects::SyntaxError
  DataMapper.auto_migrate!
end
DataMapper.auto_migrate! if options.reset_all
# db.execute('drop table if exists videoinfo') if options.reset_all || options.regen
# if !db.storage_exists?('videoinfo')

case
when options.regen && !options.reset_all
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
when options.reset_json && !options.reset_all
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

if options.maintainence
  db.execute('vacuum')
  exit
end

initlist = []

case
when options.files && options.files.respond_to?(:each)
  options.files.each do |entry|
    path = Pathname.new(entry).realpath
    initlist << path.to_s if path.file?
    if path.directory? # rubocop:disable Style/Next
      Find.find(path) do |direntry|
        if File.basename(entry)[0] == ?. # rubocop:disable Style/CharacterLiteral
          Find.prune # Don't look any further into this directory.
        else
          initlist << direntry.to_s if File.file? direntry # rubocop:disable Metrics/BlockNesting
          next
        end
      end
    end
  end
end

initlist.flatten!
initlist.uniq!

existing = {}
existing = gvi.existing
# print "#{existing}\n"
filelist = GenerateVideoInfo.genfilelist(initlist, options.debug)
filelist.delete_if { |h| existing.each { |e| h.in? e[:filename] } } unless existing.nil? || existing.empty?

case
when options.debug
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
when options.debug
  print "#{digests}\n"
  print "#{filelist}\n"
end
filelist.each do |file|
  insert = GenerateVideoInfo::Videoinfo.new
  jsondata = gvi.json(file, options.verbose) unless options.debug
  case
  when options.debug
    print "#{digests[file]}\n"
    print "#{file}\n"
  when !options.debug
    GenerateVideoInfo.genhash(file, jsondata, digests) do |h|
      begin
        puts Mood.happy("Writing metadata for #{File.basename(file)}")
        insert.attributes = h
        insert.save
      rescue DataMapper::SaveFailureError
        insert.errors.each { |e| puts e } if options.debug
      end
    end
  end
  print "#{GenerateVideoInfo.genhash(file, jsondata, digests)}\n" if options.debug || options.verbose
end
