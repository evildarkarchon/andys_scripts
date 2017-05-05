#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'find'

# require_relative 'andyrb/mood'
require_relative 'andyrb/util/hashfile'
require_relative 'andyrb/core/sort'
require_relative 'andyrb/core/cleanup'
require_relative 'andyrb/videoinfo/database'
require_relative 'andyrb/videoinfo/filelist'
require_relative 'andyrb/videoinfo/genhash'
require_relative 'andyrb/options'

Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)

opts = Options.new(ARGV.dup.cleanup) do |defaults|
  defaults[:reset_json] = false
  defaults[:reset_all] = false
  defaults[:verbose] = false
end
opts.construct! do |h, i|
  h.on('--reset-json', 'Purges the JSON caches for all databases found.') { i[:reset_json] = true }
  h.on('--reset-all', 'Resets the entire database.') { i[:reset_all] = true }
  h.on('--verbose', '-v', 'Make this script extra chatty.') { i[:verbose] = true }
end
def opts.directory
  outdir = @source.nil? || @source.empty? ? %w[/data/Private] : @source
  outdir.keep_if { |d| File.directory?(d) } if outdir.respond_to?(:keep_if)
  outdir
end

# Args, dir = args.call
dir = opts.directory

DataMapper::Model.raise_on_save_failure = true
DataMapper::Logger.new($stdout, :debug) if opts[:verbose]

directories = []
if dir.respond_to?(:each)
  dir.each do |i|
    directories = VideoInfo::Database.find(i, opts[:verbose])
    # directories.cleanup!
    # puts 'directories 1:'
    # print "#{directories}\n"
  end
else
  directories = VideoInfo::Database.find(dir, opts[:verbose])
  # directories.cleanup!
  # puts 'directories 1:'
  # print "#{directories}\n"
end

filelist = []
initlist = []

if directories.respond_to?(:each)
  directories.each do |d|
    dbpath = Pathname.new(d).realpath
    dbpath = dbpath.dirname if dbpath.file?
    DataMapper.setup(:default, "sqlite:#{dbpath.join('videoinfo.sqlite')}")
    DataMapper.finalize
    # puts "Bad #{dbpath}" unless dbpath.join('videoinfo.sqlite').exist?
    VideoInfo::Database::Videoinfo.auto_migrate! unless opts[:reset_json]
    VideoInfo::Database::Videojson.auto_migrate! if [opts[:reset_json], opts[:reset_all]].any?

    initlist << dbpath.find.to_a
    # puts 'directories 2m:'
    # print "#{initlist}\n"
    # puts
    initlist.cleanup!
    initlist.keep_if { |i| File.file?(i) }
    initlist.map!(&:to_s)

    filelist = VideoInfo.genfilelist(initlist).natsort
    # puts 'directories 3m:'
    # print "#{filelist}\n"
    # puts
  end
else
  # dbpath = Pathname.new(directories[0]) if directories.is_a?(Array)
  # dbpath = Pathname.new(directories).realpath unless directories.is_a?(Array)
  dbpath = Pathname.new(directories).realpath
  dbpath = dbpath.dirname if dbpath.file?
  # dir = dbpath.to_s

  DataMapper.setup(:default, "sqlite:#{dbpath.join('videoinfo.sqlite')}")
  DataMapper.finalize
  # puts "Bad #{dbpath}" unless dbpath.join('videoinfo.sqlite').exist?
  # VideoInfo::Database::Videoinfo.auto_migrate! unless opts[:reset_json]
  # VideoInfo::Database::Videojson.auto_migrate! if opts[:reset_json] || opts[:reset_all]
  case
  when opts[:reset_json]
    VideoInfo::Database::Videojson.auto_migrate!
  when opts[:reset_all]
    VideoInfo::Database::Videoinfo.auto_migrate!
    VideoInfo::Database::Videojson.auto_migrate!
  else
    VideoInfo::Database::Videoinfo.auto_migrate!
  end

  # Find.find(dir) do |path|
  #   Find.prune if File.basename(path)[0].include?('.') # Don't look any further into this directory.
  #   file = File.file?(path)
  #   next unless file
  #   puts path if Args.debug
  #   initlist << path if file
  # end
  initlist = dbpath.find.to_a
  initlist.keep_if(&:file?).map!(&:to_s).cleanup!.freeze
  # puts 'directories 2s:'
  # print "#{initlist}\n"
  # puts

  filelist = VideoInfo.genfilelist(initlist).natsort
  filelist.freeze unless frozen?
  # puts 'directories 3s:'
  # print "#{filelist}\n"
  # puts

  # filelist.each do |i|
  #   filepath = Pathname.new(i)
  #   filelist.delete(i) unless filepath.file?
  #   puts 'Bad' unless filepath.file?
  # end
  # puts filelist
end

digests = Util.hashfile(filelist).freeze

filelist.each do |file|
  filepath = Pathname.new(file).freeze
  FileUtils.touch(file) unless filepath.file?

  DataMapper.setup(:default, "sqlite:#{filepath.dirname.join('videoinfo.sqlite')}") if filepath.file?
  DataMapper.setup(:default, "sqlite:#{filepath.join('videoinfo.sqlite')}") if filepath.directory?
  gvi = VideoInfo::Database::Data.new(filepath.dirname.join('videoinfo.sqlite').to_s, opts[:verbose]) if filepath.file?
  gvi = VideoInfo::Database::Data.new(filepath.join('videoinfo.sqlite').to_s, opts[:verbose]) if filepath.directory?
  insert = VideoInfo::Database::Videoinfo.new

  jsondata = gvi.json(file, opts[:verbose])
  jsondata.freeze unless frozen?
  # print "#{jsondata}\n"
  # puts jsondata

  VideoInfo.genhash(file, jsondata, digests) do |h|
    begin
      puts(Mood.happy { "Writing metadata for #{File.basename(file)}" })
      insert.attributes = h
      insert.save
    rescue DataMapper::SaveFailureError
      insert.errors.each { |e| puts e } if opts[:verbose]
    end
  end

  digests.delete(file)
end
