#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'find'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.db = Pathname.new('./videoinfo.sqlite')
    options.debug = false

    optparse = OptionParser.new do |opts|
      opts.on('-db', "--database file", 'Location where the database will be written') { |db| options.db = Pathname.new(db) } # rubocop:disable Style/StringLiterals
      opts.on('-d', '--debug', "Don't actually do anything, just print what would be done.") { |debug| options.debug = debug }
      opts.on('-m', '--maintainence', 'Performs simple maintainence operations on the database.') { |m| options.m = m }
      opts.on('-r', '--regen', 'Drops and recreates the videoinfo table (used for schema changes, testing, etc.)') { |regen| options.regen = regen }
      opts.on('--regen-json', 'Drops and recreates the videojson table.') { |regen_json| options.regen_json = regen_json }
      opts.on('--reset-all', 'Drops and recreates both the videoinfo and videojson tables.') { |regen_all| options.regen_all = regen_all }
    end
    optparse.parse!(args)
    options
  end
end
options = Options.parse(ARGV)
options.files = []
options.files = ARGV unless ARGV.nil? || ARGV.empty?
if options.files.empty?
  Find.find(Pathname.getwd.to_s) do |path|
    if File.basename(path)[0] == ?. # rubocop:disable Style/CharacterLiteral
      Find.prune # Don't look any further into this directory.
    else
      puts path if options.debug
      options.files << path
      next
    end
  end
end
if options.debug
  puts options
  puts options.files
end

vi = VideoInfo::Database.new(options.db.to_s)
gvi = VideoInfo::Generate.new(options.db.to_s)

if options.reset_json && !options.reset_all
  vi.resetjson
  exit
end
vi.resetvideoinfo if options.regen || options.reset_all

vi.resetjson if options.reset_all

if options.maintainence
  vi.vacuum
  exit
end

initlist = []
if options.files && options.files.respond_to?(:each)
  options.files.each do |entry|
    path = Pathname.new(entry).realpath
    initlist << path.to_s if path.file?
    path.descend { |file| initlist << file.to_s if file.file? } if path.directory?
  end
end

existing = gvi.existing
filelist = Util::SortEntries.sort(VideoInfo::Generate.filelist(initlist, existing, options.debug))
if options.debug
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

if filelist.empty?
  puts(Mood.happy('All files already in the database or there are no media files.'))
  exit
end

digests = VideoInfo::Generate.digest(filelist)
filelist.each do |file|
  puts(Mood.happy("Extracting metadata from #{file}"))
  jsondata = gvi.json(file, options.debug)
  metadata = VideoInfo::Generate.hash(file, jsondata, digests[file])
  gvi.write(metadata, jsondata, options.debug)
end
