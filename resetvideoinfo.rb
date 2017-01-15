#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'find'

# require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo_dm'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.reset_json = false
    options.reset_all = false
    options.verbose = false
    # options.del = false

    optparse = OptionParser.new do |opts|
      opts.on('--reset-json', 'Purges the JSON caches for all databases found.') { |j| options.reset_json = j }
      opts.on('--reset-all', 'Resets the entire database.') { |a| options.reset_all = a }
      opts.on('-v', '--verbose', 'Makes this script extra chatty') { |v| options.verbose = v }
      # opts.on('--delete', 'Only drop and recreate tables.') { |del| options.del = del }
    end
    optparse.parse!(args)
    options
  end
end
options = Options.parse(ARGV)
options.directory = ARGV unless ARGV.nil? || ARGV.empty?
options.directory = ['/data/Private'] if ARGV.nil? || ARGV.empty?

DataMapper::Model.raise_on_save_failure = true
DataMapper::Logger.new($stdout, :debug) if options.verbose

directories = []
if options.directory.respond_to?(:each)
  options.directory.each do |i|
    directories << GenerateVideoInfo.find(i, true)
    directories.compact!
    directories.uniq!
    directories.flatten!
  end
else
  directories << GenerateVideoInfo.find(options.directory, true)
  directories.compact!
  directories.uniq!
  directories.flatten!
end

directories = directories.join('') if directories.respond_to?(:each) && directories.respond_to?(:length) && directories.length == 1
filelist = []
initlist = []

if directories.respond_to?(:each) && directories.respond_to?(:length) && directories.length > 1
  directories.each do |d|
    dbpath = Pathname.new(d).realpath
    dbpath = dbpath.dirname if dbpath.file?
    dir = dbpath.to_s
    DataMapper.setup(:default, "sqlite:#{dbpath.join('videoinfo.sqlite')}")
    DataMapper.finalize
    # puts "Bad #{dbpath}" unless dbpath.join('videoinfo.sqlite').exist?
    GenerateVideoInfo::Videoinfo.auto_migrate! unless options.reset_json == true
    GenerateVideoInfo::Videojson.auto_migrate! if options.reset_json == true || options.reset_all == true
    Find.find(dir) do |path|
      if File.basename(path)[0] == ?. # rubocop:disable Style/CharacterLiteral
        Find.prune # Don't look any further into this directory.
      else
        initpath = Pathname.new(path.to_s)
        initlist << initpath.to_s if initpath.file?
        next
      end
    end
    initlist.flatten!
    initlist.compact!
    initlist.uniq!
    filelist = Util::SortEntries.sort(GenerateVideoInfo.genfilelist(initlist))
    filelist.each do |i|
      filepath = Pathname.new(i)
      filelist.delete(i) unless filepath.file?
      # puts "Bad #{filepath}" unless filepath.file?
    end
  end
else
  dbpath = Pathname.new(directories).realpath
  dbpath = dbpath.dirname if dbpath.file?
  dir = dbpath.to_s

  DataMapper.setup(:default, "sqlite:#{dbpath.join('videoinfo.sqlite')}")
  DataMapper.finalize
  # puts "Bad #{dbpath}" unless dbpath.join('videoinfo.sqlite').exist?
  GenerateVideoInfo::Videoinfo.auto_migrate! unless options.reset_json == true
  GenerateVideoInfo::Videojson.auto_migrate! if options.reset_json == true || options.reset_all == true
  Find.find(dir) do |path|
    if File.basename(path)[0] == ?. # rubocop:disable Style/CharacterLiteral
      Find.prune # Don't look any further into this directory.
    else
      initlist << path.to_s if File.file? path
      next
    end
  end
  initlist.flatten!
  initlist.compact!
  initlist.uniq!
  filelist = Util::SortEntries.sort(GenerateVideoInfo.genfilelist(initlist))
  filelist.each do |i|
    filepath = Pathname.new(i)
    filelist.delete(i) unless filepath.file?
    # puts 'Bad' unless filepath.file?
  end
  # puts filelist
end

digests = Util.hashfile(filelist)

filelist.each do |file|
  filepath = Pathname.new(file)
  # puts filepath.dirname
  FileUtils.touch(file) unless filepath.file?
  DataMapper.setup(:default, "sqlite:#{filepath.dirname.join('videoinfo.sqlite')}") if filepath.file?
  DataMapper.setup(:default, "sqlite:#{filepath.join('videoinfo.sqlite')}") if filepath.directory?
  gvi = GenerateVideoInfo::Data.new(filepath.dirname.join('videoinfo.sqlite').to_s, options.verbose) if filepath.file?
  gvi = GenerateVideoInfo::Data.new(filepath.join('videoinfo.sqlite').to_s, options.verbose) if filepath.directory?
  insert = GenerateVideoInfo::Videoinfo.new
  # db = DataMapper.repository(:default).adapter
  name = filepath.to_s
  jsondata = gvi.json(name, options.verbose)
  GenerateVideoInfo.genhash(file, jsondata, digests) do |h|
    begin
      puts Mood.happy("Writing metadata for #{File.basename(file)}")
      insert.attributes = h
      insert.save
    rescue DataMapper::SaveFailureError
      insert.errors.each { |e| puts e } if options.verbose
    end
  end
  digests.delete(name)
end