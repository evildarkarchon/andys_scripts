#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'fileutils'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.db = Pathname.new('./videoinfo.sqlite')
    options.gvi = true
    options.sort = true
    options.ffmpeg = false
    options.output = Pathname.getwd
    options.outputdb = nil
    options.backup = nil
    options.combine = false
    options.debug = false

    optparse = OptionsParser.new do |opts|
      opts.on('--database file', 'Database to read metadata from (if any).') { |db| options.db = Pathname.new(db) }
      opts.on('-f', '--ffmpeg', 'Use ffmpeg instead of mkvmerge. Note: ffmpeg hates mpeg2-ps files.') { |f| options.ffmpeg = f }
      opts.on('-c', '--combine', 'Run in concatenation mode.') { |c| options.combine = c }
      opts.on('--no-sort', "Don't sort the list of files to be muxed.") { options.sort = false }
      opts.on('--no-gvi', "Don't generate video info for the muxed files.") { options.gvi = false }
      opts.on('-o directory', '--output directory', 'Directory where the muxed files will be located. (defaults to current directory)') { |dir| options.output = dir }
      opts.on('-b directory', '--backup directory', 'Directory where the source files will be moved.') { |dir| options.backup = Pathname.new(dir) }
      opts.on('--output-database file', 'File name for the output videoinfo database (if any)') { |db| options.outputdb = Pathname.new(db) }
      opts.on('--debug', '-d', "Print what would be done, but don't actually do it") { |debug| options.debug = debug }
    end
    optparse.parse!(args)
    options
  end
end
options = Options.parse(ARGV)
options.files = Util::SortEntries.sort(ARGV) if options.sort == true
options.files = ARGV unless options.sort == true

mkvpropedit = Util::FindApp.which('mkvpropedit')
ffmpeg = Util::FindApp.which('ffmpeg')
mkvmerge = Util::FindApp.which('mkvmerge')

raise 'Can not find ffmpeg and ffmpeg mode was requested.' if ffmpeg.nil? && options.ffmpeg
raise 'Can not find mkvmerge and mkvmerge was requested.' if mkvmerge.nil? && !options.ffmpeg
raise 'Can not find mkvpropedit.' if mkvpropedit.nil? && options.ffmpeg

vi = nil
vi = VideoInfo::Database.new(options.db.to_s) if options.db.exists?
gvi = nil
gvi = VideoInfo::Generate.new(options.db.to_s) if options.db.exists? && options.gvi && !options.outputdb
gvi = VideoInfo::Generate.new(options.outputdb.to_s) if options.outputdb && options.gvi

def genvi(filename)
  filepath = Pathname.new(filename).realpath
  puts Mood.happy("Calculating hash for #{filepath}")
  outhash = Util::HashFile.genhash(filepath.to_s)
  jsondata = gvi.json(filename, options.debug)
  metadata = VideoInfo::Generate.hash(filename, jsondata, outhash)
  gvi.write(metadata, jsondata, options.debug)
end

def backup(filename)
  if options.backup.directory?
    puts Mood.happy("Moving #{filename} to #{options.backup}")
    FileUtils.mv(filename, options.backup.to_s)
    vi.deletefileentry(filename) unless vi.nil?
  end
end

options.output.mkpath unless options.output.exists?
def ffmpegconcat
  filelist = Tempfile.new('mkv', mode: 'a+')
  options.files.each do |file|
    dur = vi.read('select duration_raw from videoinfo where filename = ?', file)[0][0] if vi
    filelist.write("file '#{file}'\n")
    filelist.write("duration #{dur}\n") if dur
  end
  Util::Program.run([ffmpeg, '-f', 'concat', '-safe', '0', '-i', filelist.path, '-c', 'copy', '-hide_banner', '-y', options.output]) unless options.debug
  Util::Program.run([mkvpropedit, '--add-track-statistics-tags', options.output]) unless options.debug
  genvi(options.output)
  puts filelist.read if options.debug
end
