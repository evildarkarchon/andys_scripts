#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'json'
require 'filemagic'
require 'subprocess'
require 'data_mapper'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo_dm'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.videocodec = nil
    options.videobitrate = nil
    options.framerate = nil
    options.passes = 2

    options.audiocodec = nil
    options.audiobitrate = nil
    options.audiofilter = nil

    options.db = Pathname.new('./videoinfo.sqlite')
    options.converttest = true
    options.config = Pathname.new(Dir.home).join('.config/absconvert.json')
    options.container = nil
    options.sort = true
    options.debug = false

    options.backup = nil
    options.outputdir = Pathname.new('..').realpath unless Dir.pwd == Dir.home
    options.outputdir = Pathname.new(Dir.home) if Dir.pwd == Dir.home
    options.verbose = false

    optparse = OptionParser.new do |opts|
      opts.on('--video-codec [codec]', 'Video codec for the output video.') { |vcodec| options.videocodec = vcodec }
      opts.on('--video-bitrate [bitrate]', 'Video bitrate for the output video.') { |vbitrate| options.videobitrate = vbitrate }
      opts.on('--passes [pass]', '-p [pass]', 'Number of video encoding passes.') do |passes|
        raise ArgumentError unless passes.respond_to?(:to_i)
        raise ArgumentError unless passes.between?(1, 2)
        options.passes = passes.to_i
      end
      opts.on('--frame-rate [rate]', '-f [rate]', 'Manually specify the frame rate (e.g. useful for MPEG2-PS files)') { |fr| options.framerate = fr.to_f if fr.respond_to?(:to_f) }
      opts.on('--audio-bitrate [bitrate]', 'Bitrate of the output audio.') { |abitrate| options.audiobitrate = abitrate }
      opts.on('--audio-codec [codec]', 'Codec of the output audio.') { |acodec| options.audiocodec = acodec }
      opts.on('--audio-filter [filter]', 'Filter to be used for the output audio.') { |afilter| options.audiofilter = afilter }
      opts.on('--database [location]', 'Location of the videoinfo database') { |db| optons.db = Pathname.new(db) }
      opts.on('--convert-test', "Don't delete any videoinfo entries.") { |ct| options.converttest = ct }
      opts.on('--config [path]', '-c [path]', 'Location of the configuration json file') { |config| options.config = Pathname.new(config) }
      opts.on('--container [extension]', 'Container to be used for the output file (the dot must be included).') { |ext| options.container = ext }
      opts.on('--no-sort', "Don't sort the file list.") { options.sort = false }
      opts.on('--debug', '-d', 'Print variables and exit.') { options.debug = true }
      opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |backup| options.backup = Pathname.new(backup) }
      opts.on('--output [dir]', '-o [dir]', 'Location of the output directory') { |output| options.outputdir = Pathname.new(output) }
      opts.on('--verbose', '-v', 'Make the script a bit more chatty.') { |v| options.verbose = v }
    end
    optparse.parse!(args)
    options
  end
end

options = Options.parse(ARGV)
options.files = ARGV

DataMapper.setup(:default, "sqlite:#{options.db.realpath}")
DataMapper::Logger.new($stdout, :debug) if options.verbose
vi = GenerateVideoInfo::Videoinfo.new

mkvpropedit = Util::FindApp.which('mkvpropedit')
ffmpeg = Util::FindApp.which('ffmpeg')

nocodec = %w(none copy)

options.shutup = mkvpropedit # remove these 2 when these variables are actually used.
options.shutup2 = vi

raise 'ffmpeg not found.' if ffmpeg.nil?

config = File.open options.config { |configfile| JSON.parse configfile } if File.exist? options.config
# unless defined?(config) && config.respond_to?(:to_h)
#  defaults = Util.block do
#    out = {}
#
#    out
# end
#  options.shutup5 = defaults
# end
options.shutup3 = config
def backup(source, backupdir)
  backuppath = Pathname.new(backupdir)
  sourcepath = Pathname.new(source)

  backup.mkpath unless backuppath.exist?
  raise 'Backup directory is a file.' if backuppath.exist? && backuppath.file?
  sourcepath.rename(backuppath.join(sourcepath.basename)) if sourcepath.exist?
end

db = Class.new do
  define_method :bitrate do |file|
    path = Pathname.new(file).basename.to_s
    query = GenerateVideoInfo::Videoinfo.all(filename: path, fields: [:bitrate_0_raw, :type_0, :bitrate_1_raw, :type_1])

    bitrates = {}

    bitrates['video'] = query[0][:bitrate_0_raw] if query[0][:type_0] == 'video'
    bitrates['video'] = query[0][:bitrate_1_raw] if query[0][:type_1] == 'video'

    bitrates['audio'] = query[0][:bitrate_0_raw] if query[0][:type_0] == 'audio'
    bitrates['audio'] = query[0][:bitrate_1_raw] if query[0][:type_1] == 'audio'

    bitrates
  end
end

command = Class.new do
  define_method :list do |filename, passnum, passmax|
    raise ArgumentError unless passnum.between?(1, 2)
    raise ArgumentError unless passmax.between?(1, 2)
    cmd = ['ffmpeg', '-i', filename]
    cmd << ['-c:v', options.videocodec] unless options.videocodec.nil? || options.videocodec == 'none'
    cmd << '-vn' if options.videocodec.nil? || options.videocodec == 'none'
    cmd << ['-b:v', db.new.bitrate(filename)] if options.videobitrate.nil? && !options.videocodec.in?(nocodec)
    cmd << ['-b:v', options.videobitrate] if !options.videobitrate.nil? && !options.videocodec.in?(nocodec)
  end
end
options.files.each do |file|
  options.shutup4 = file
  framerates = Util.block do
    filepath = Pathname.new(file).basename.to_s
    dbinfo = GenerateVideoInfo::Videoinfo.all(filename: filepath, fields: [:frame_rate])
    frame_rate = dbinfo[0][:frame_rate]
    frame_rate
  end
  options.shutup5 = framerates
  options.shutup6 = bitrate

  options.shutup7 = cmdline
  backup(file, options.backup) if options.backup
  # insert command-line generation, command invocation, backup and database cleanup code here.
end
