#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'json'
require 'filemagic'
require 'subprocess'
require 'data_mapper'
require 'shellwords'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/videoinfo_dm'

# rubocop:disable Style/CaseIndentation

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.videocodec = nil
    options.videocodecopts = nil
    options.videobitrate = nil
    options.framerate = nil
    options.passes = 2

    options.audiocodec = nil
    options.audiocodecopts = nil
    options.audiobitrate = nil
    options.audiofilter = nil

    options.db = Pathname.new('./videoinfo.sqlite')
    options.converttest = true
    options.config = Pathname.new(Dir.home).join('.config/absconvert.json')
    options.container = nil
    options.sort = true
    options.debug = false

    options.backup = nil
    options.outputdir = case od
    when Dir.pwd == Dir.home
      Pathname.new(Dir.home)
    else
      Pathname.new('..').realpath
    end # rubocop:disable Lint/EndAlignment
    options.verbose = false

    optparse = OptionParser.new do |opts|
      opts.on('--video-codec [codec]', 'Video codec for the output video.') do |vcodec|
        options.videocodec = case vc
        when vcodec == 'none'
          options.novideo = true
          nil
        else
          vcodec
        end # rubocop:disable Lint/EndAlignment
      end
      opts.on('--video-bitrate [bitrate]', 'Video bitrate for the output video.') { |vbitrate| options.videobitrate = vbitrate }
      opts.on('--passes [pass]', '-p [pass]', 'Number of video encoding passes.') do |passes|
        raise ArgumentError unless passes.respond_to?(:to_i)
        raise ArgumentError unless passes.between?(1, 2)
        options.passes = passes.to_i
      end
      opts.on('--video-codec-opts [opts]', 'Options to pass to the video codec') { |vco| options.videocodecopts = vco.shellsplit }
      opts.on('--frame-rate [rate]', '-f [rate]', 'Manually specify the frame rate (e.g. useful for MPEG2-PS files)') { |fr| options.framerate = fr.to_f if fr.respond_to?(:to_f) }
      opts.on('--no-video', 'Disable video channel') { |nv| options.videocodec = nil; options.novideo == nv } # rubocop:disable Style/Semicolon
      opts.on('--audio-bitrate [bitrate]', 'Bitrate of the output audio.') { |abitrate| options.audiobitrate = abitrate }
      opts.on('--audio-codec [codec]', 'Codec of the output audio.') do |acodec|
        options.audiocodec = case ac
        when acodec == 'none'
          options.noaudio = true
          nil
        else
          acodec
        end # rubocop:disable Lint/EndAlignment
      end
      opts.on('--audio-filter [filter]', 'Filter to be used for the output audio.') { |afilter| options.audiofilter = afilter }
      opts.on('--audio-codec-opts [opts]', 'Options to pass to the audio codec.') { |aco| options.audiocodecopts = aco.shellsplit }
      opts.on('--no-audio', 'Disable audio channel') { |na| options.audiocodec = nil; options.noaudio = na } # rubocop:disable Style/Semicolon
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
# vi = GenerateVideoInfo::Videoinfo.new

mkvpropedit = Util::FindApp.which('mkvpropedit')
ffmpeg = Util::FindApp.which('ffmpeg')

raise 'ffmpeg not found.' if ffmpeg.nil?

config = File.open options.config { |configfile| JSON.parse configfile } if File.exist? options.config

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

    bitrates[:video] = query[0][:bitrate_0_raw] if query[0][:type_0] == 'video'
    bitrates[:video] = query[0][:bitrate_1_raw] if query[0][:type_1] == 'video'

    bitrates[:audio] = query[0][:bitrate_0_raw] if query[0][:type_0] == 'audio'
    bitrates[:audio] = query[0][:bitrate_1_raw] if query[0][:type_1] == 'audio'

    bitrates
  end
  define_method :frame_rate do |filename|
    filepath = Pathname.new(filename)
    dbinfo = GenerateVideoInfo::Videoinfo.all(filename: filepath.basename.to_s, fields: [:frame_rate])
    frame_rate = dbinfo[0][:frame_rate]
    frame_rate
  end
end
command = Class.new do
  define_method :list do |filename, passmax, passnum = nil|
    filepath = Pathname.new(filename)
    bitrates = db.new.bitrate(filename)
    framerate = case fr
    when options.framerate
      options.framerate
    else
      db.new.frame_rate(filename)
    end # rubocop:disable Lint/EndAlignment
    vcodec = case vc
    when options.novideo
      '-vn'
    when config['defaults']['video']
      ['-c:v', config['defaults']['video']]
    when options.videocodec
      ['-c:v', options.videocodec]
    end # rubocop:disable Lint/EndAlignment

    unless options.novideo
      vbitrate = case vb
      when options.videobitrate
        options.videobitrate
      when bitrates[:video]
        bitrates[:video]
      end # rubocop:disable Lint/EndAlignment
    end

    unless options.novideo
      vcodecopts = case vco
      when config['codecs'][options.videocodec]
        config['codecs'][options.videocodec]
      when options.videocodecopts
        options.videocodecopts
      end # rubocop:disable Lint/EndAlignment
    end

    acodec = case ac
    when passnum == 1, options.noaudio
      '-an'
    when !config['defaults']['audio']
      config['defaults']['audio']
    when options.audiocodec
      ['-c:a', options.audiocodec]
    end # rubocop:disable Lint/EndAlignment

    unless options.noaudio
      acodecopts = case aco
      when config['codecs'][options.audiocodec]
        config['codecs'][options.audiocodec]
      when options.audiocodecopts
        options.audiocodecopts
      end # rubocop:disable Lint/EndAlignment
    end

    unless options.noaudio
      abitrate = case ab
      when options.audiobitrate
        options.audiobitrate
      when bitrates[:audio]
        bitrates[:audio]
      end # rubocop:disable Lint/EndAlignment
    end

    if !options.noaudio && opitions.audiofilter || !options.noaudio && config['defaults']['audiofilter']
      afilter = case af
      when config['defaults']['audiofilter']
        config['defaults']['audiofilter']
      when options.audiofilter
        options.audiofilter
      else
        'aresample=async=1:min_comp=0.001:first_pts=0'
      end # rubocop:disable Lint/EndAlignment
    end

    raise ArgumentError unless passnum.between?(1, 2)
    raise ArgumentError unless passmax.between?(1, 2)
    cmd = ['ffmpeg', '-i', filename]
    cmd << vcodec
    cmd << ['-pass', passnum] if passmax == 2
    cmd << vbitrate if vbitrate
    cmd << ['-pass', passnum, '-passlogfile', filepath.sub_ext('')] if passmax == 2
    cmd << vcodecopts if vcodecopts
    cmd << ['-filter:v', "fps = #{framerate}"] if framerate
    cmd << acodec
    cmd << abitrate if abitrate
    cmd << acodecopts if acodecopts
    cmd << afilter if afilter
    cmd << ['-hide_banner', '-y']
    cmd << case output
    when passnum == 1 && passmax == 2
      ['-format', 'matroska', '/dev/null']
    when passnum == 2 && passmax == 2, passmax = 1
      options.outputdir.join(filepath.basename.to_s).to_s
    end # rubocop:disable Lint/EndAlignment
    cmd.flatten!
  end
end
options.files.each do |file|
  filepath = Pathname.new(file)
  if options.passes == 2
    cmdpass1 = command.new.list(file, passnum: 1, passmax: 2)
    cmdpass2 = command.new.list(file, passnum: 2, passmax: 2)
  elsif options.passes == 1
    cmd1pass = command.new.list(file, passmax: 1)
  end
  begin
    Util::Program.runprogram(cmdpass1) if options.passes == 2
    Util::Program.runprogram(cmdpass2) if options.passes == 2
    Util::Program.runprogram(cmd1pass) if options.passes == 1
  rescue Subprocess::NonZeroExit => e
    raise e
  else
    Util::Program.runprogram([mkvpropedit, '--add-track-statistics-tags', options.outputdir.join(filepath.basename.to_s).to_s])
    del = GenerateVideoInfo::Videoinfo.all(filename: sourcepath.basename.to_s)
    deljson = GenerateVideoInfo::Videojson.all(filename: sourcepath.basename.to_s)
    del.destroy
    deljson.destroy
  end

  backup(file, options.backup) if options.backup
  # insert command-line generation, command invocation, backup and database cleanup code here.
end
