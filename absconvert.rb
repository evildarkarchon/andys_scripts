#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'json'
require 'filemagic'
require 'subprocess'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo'

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

    options.dbpath = Pathname.new('./videoinfo.sqlite')
    options.converttest = true
    options.config = Pathname.new(Dir.home).join('.config/absconvert.json')
    options.container = nil
    options.sort = true
    options.debug = false

    options.backup = nil
    options.outputdir = Pathname.new('..').realpath unless Dir.pwd == Dir.home
    options.outputdir = Pathname.new(Dir.home) if Dir.pwd == Dir.home

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
      opts.on('--database [location]', 'Location of the videoinfo database') { |db| options.dbpath = Pathname.new(db) }
      opts.on('--convert-test', "Don't delete any videoinfo entries.") { |ct| options.converttest = ct }
      opts.on('--config [path]', '-c [path]', 'Location of the configuration json file') { |config| options.config = Pathname.new(config) }
      opts.on('--container [extension]', 'Container to be used for the output file (the dot must be included).') { |ext| options.container = ext }
      opts.on('--no-sort', "Don't sort the file list.") { options.sort = false }
      opts.on('--debug', '-d', 'Print variables and exit.') { options.debug = true }
      opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |backup| options.backup = Pathname.new(backup) }
      opts.on('--output [dir]', '-o [dir]', 'Location of the output directory') { |output| options.outputdir = Pathname.new(output) }
    end
    optparse.parse!(args)
    options
  end
end

options = Options.parse(ARGV)
options.files = ARGV

vi = VideoInfo::Database.new(options.dbpath.to_s)

mkvpropedit = Util::FindApp.which('mkvpropedit')
ffmpeg = Util::FindApp.which('ffmpeg')

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

options.files.each do |file|
  options.shutup4 = file
  bitrate = Util.block do
    path = Pathname.new(file).basename.to_s
    dbinfo = vi.readhash('select bitrate_0_raw, bitrate_1_raw, type_0, type_1 from videoinfo where filename=?', path)
    # print "#{dbinfo}\n"
    bitrates = {}

    bitrates['video'] = dbinfo['bitrate_0_raw'].to_s if dbinfo['type_0'].to_s == 'video'
    bitrates['video'] = dbinfo['bitrate_1_raw'].to_s if dbinfo['type_1'].to_s == 'video'

    bitrates['audio'] = dbinfo['bitrate_0_raw'].to_s if dbinfo['type_0'].to_s == 'audio'
    bitrates['audio'] = dbinfo['bitrate_1_raw'].to_s if dbinfo['type_1'].to_s == 'audio'

    bitrates
  end
  framerates = Util.block do
    filepath = Pathname.new(file).basename.to_s
    dbinfo = vi.read('select frame_rate from videoinfo where filename = ?', filepath)
    dbinfo
  end
  options.shutup5 = framerates
  options.shutup6 = bitrate

  cmdline = Util.block do
    cmd = [ffmpeg, '-i', file]
    
    cmd
  end

  backup(file, options.backup) if options.backup
  # insert command-line generation, command invocation, backup and database cleanup code here.
end
