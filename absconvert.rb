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
require_relative 'andyrb/videoinfo'
# rubocop:disable Style/CaseIndentation, Lint/EndAlignment, Lint/UnneededDisable
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

    options.db = Pathname.getwd + 'videoinfo.sqlite'
    options.converttest = true
    options.config = Pathname.new(Dir.home) + '.config/absconvert.json'
    options.container = nil
    options.sort = true
    options.debug = false

    options.backup = nil
    options.converttest = false
    options.stats = true
    options.outputdir = case
    when Dir.pwd == Dir.home
      Pathname.new(Dir.home)
    else
      Pathname.getwd.parent
    end
    options.verbose = false

    optparse = OptionParser.new do |opts|
      opts.on('--video-codec [codec]', 'Video codec for the output video.') do |vcodec|
        options.videocodec = case
        when vcodec == 'none'
          options.novideo = true
          nil
        else
          vcodec
        end
      end

      opts.on('--video-bitrate [bitrate]', 'Video bitrate for the output video.') { |vbitrate| options.videobitrate = vbitrate }

      opts.on('--passes [pass]', '-p [pass]', 'Number of video encoding passes.') do |passes|
        case
        when !passes.respond_to?(:to_i)
          raise 'Argument passed is not an integer or convertible to an integer.'
        when !passes.between?(1, 2)
          options.passes = 1 if passes <= 0
          puts Mood.neutral('Passes argument is less than or equal to 0, setting passes to 1') if passes <= 0
          options.passes = 2 if passes >= 3
          puts Mood.neutral('Passes argument is greater than or equal to 3, setting to 2') if passes >= 3
        else
          options.passes = passes.to_i
        end
      end

      opts.on('--video-codec-opts [opts]', 'Options to pass to the video codec') { |vco| options.videocodecopts = vco.shellsplit }
      opts.on('--frame-rate [rate]', '-f [rate]', 'Manually specify the frame rate (e.g. useful for MPEG2-PS files)') { |fr| options.framerate = fr.to_f if fr.respond_to?(:to_f) }

      opts.on('--no-video', 'Disable video channel') do
        options.videocodec = nil
        options.novideo = true
      end

      opts.on('--audio-bitrate [bitrate]', 'Bitrate of the output audio.') { |abitrate| options.audiobitrate = abitrate }

      opts.on('--audio-codec [codec]', 'Codec of the output audio.') do |acodec|
        options.audiocodec = case
        when acodec == 'none'
          options.noaudio = true
          nil
        else
          acodec
        end
      end

      opts.on('--audio-filter [filter]', 'Filter to be used for the output audio.') { |afilter| options.audiofilter = afilter }
      opts.on('--audio-codec-opts [opts]', 'Options to pass to the audio codec.') { |aco| options.audiocodecopts = aco.shellsplit }
      opts.on('--no-audio', 'Disable audio channel') do
        options.audiocodec = nil
        options.noaudio = true
      end

      opts.on('--database [location]', 'Location of the videoinfo database') { |db| optons.db = Pathname.new(db) }
      opts.on('--convert-test', "Don't delete any videoinfo entries.") { options.converttest = true }
      opts.on('--config [path]', '-c [path]', 'Location of the configuration json file') { |config| options.config = Pathname.new(config) }
      opts.on('--container [extension]', 'Container to be used for the output file (the dot must be included).') { |ext| options.container = ext }
      opts.on('--no-sort', "Don't sort the file list.") { options.sort = false }
      opts.on('--no-stats', "Don't add statistics tags to the output file(s)") { options.stats = false }
      opts.on('--debug', '-d', 'Print variables and exit.') { options.debug = true }
      opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |backup| options.backup = Pathname.new(backup) }
      opts.on('--output [dir]', '-o [dir]', 'Location of the output directory') { |output| options.outputdir = Pathname.new(output) }
      opts.on('--verbose', '-v', 'Make the script a bit more chatty.') { options.verbose = true }
      opts.on('--convert-test', "Don't delete any database entries.") { options.converttest = true }
    end
    optparse.parse!(args)
    options
  end
end

Args = Options.parse(ARGV)
Args.files = ARGV
Args.files.keep_if { |filename| Pathname.new(filename).file? } if Args.files.respond_to?(:keep_if)

DataMapper.setup(:default, "sqlite:#{Args.db.realpath}")
DataMapper::Logger.new($stdout, :debug) if Args.verbose
# vi = GenerateVideoInfo::Videoinfo.new

MkvPropEdit = Util::FindApp.which('mkvpropedit')
FFmpeg = Util::FindApp.which('ffmpeg')

raise 'ffmpeg not found.' if FFmpeg.nil?
raise 'mkvpropedit not found' if (MkvPropEdit.nil? || MkvPropEdit.empty?) && Args.stats
raise 'ffmpeg is not executable' unless FFmpeg && !File.executable?(FFmpeg)
raise 'mkvpropedit is not executable' unless (MkvPropEdit && File.executable?(MkvPropEdit) && Args.stats) || !Args.stats

Config = case # rubocop:disable Style/ConstantName
when File.exist?(Args.config)
  config = nil
  File.open(Args.config) do |cf|
    config = JSON.parse(cf.read)
  end
  config = Util.recursive_symbolize_keys(config)
  print "#{config}\n" if Args.debug && config
  config
end

def backup(sourcefile, backupdir)
  backuppath = Pathname.new(backupdir)
  sourcepath = Pathname.new(sourcefile)

  backup.mkpath unless backuppath.exist?
  raise 'Backup directory is a file.' if backuppath.exist? && backuppath.file?
  puts Mood.happy { "Moving #{sourcefile} to #{backupdir}" }
  sourcepath.rename(backuppath.join(sourcepath.basename)) if sourcepath.exist?
end

class Database
  attr_reader :bitrates, :frame_rate
  def initialize(filename)
    path = Pathname.new(filename).basename.to_s
    @query = GenerateVideoInfo::Videoinfo.all(filename: path, fields: [:bitrate_0_raw, :type_0, :bitrate_1_raw, :type_1, :frame_rate])
    @frame_rate = nil
    @bitrates = {}
    @bitrates[:video] = nil
    @bitrates[:audio] = nil
  end

  def bitrate!
    @bitrates[:video] = case
    when Args.videobitrate
      Args.videobitrate
    when @query[0][:type_0] == 'video'
      @query[0][:bitrate_0_raw]
    when @query[0][:type_1] == 'video'
      @query[0][:bitrate_1_raw]
    end

    @bitrates[:audio] = case
    when Args.audiobitrate
      Args.audiobitrate
    when @query[0][:type_0] == 'audio'
      @query[0][:bitrate_0_raw]
    when @query[0][:type_1] == 'audio'
      @query[0][:bitrate_1_raw]
    end
  end

  def framerate!
    @frame_rate = case
    when Args.framerate
      Args.framerate
    when @query[0][:frame_rate]
      @query[0][:frame_rate]
    end
  end
end

class Command
  attr_reader :list
  def initialize(filename, passnum, passmax)
    filepath = Pathname.new(filename)
    db = Database.new(filename)
    db.bitrate!
    db.framerate! unless Args.novideo
    bitrates = db.bitrates
    framerate = case
    when !Args.novideo && Args.framerate
      Args.framerate
    when !Args.novideo && db.frame_rate
      db.frame_rate
    end
    vcodec = case
    when Args.novideo || bitrates[:video].nil?
      '-vn'
    when Config[:defaults][:video]
      %W(-c:v #{Config[:defaults][:video]})
      # ['-c:v', Config['defaults']['video']]
    when Args.videocodec
      %W(-c:v #{Args.videocodec})
      # ['-c:v', Args.videocodec]
    end

    vbitrate = case
    when !Args.novideo && bitrates[:video]
      %W(-b:v #{bitrates[:video]})
      # ['-b:v', bitrates[:video].to_s]
    end

    vcodecopts = case
    when !Args.novideo && Args.videocodecopts
      Args.videocodecopts
    when !Args.novideo && Config[:defaults][Args.videocodec.to_sym]
      Config[:codecs][Args.videocodec.to_sym]
    end

    acodec = case
    when passnum == 1 || Args.noaudio || bitrates[:audio].nil?
      '-an'
    when Args.audiocodec
      # ['-c:a', Args.audiocodec]
      %W(-c:a #{Args.audiocodec})
    when Config[:defaults][:audio]
      Config[:defaults][:audio]
    else
      %w(-c:a libopus)
      # ['-c:a', 'libopus']
    end

    acodecopts = case
    when !Args.noaudio && Args.audiocodecopts
      Args.audiocodecopts
    when !Args.noaudio && Config[:codecs][Args.audiocodec.to_sym]
      Config[:codecs][Args.audiocodec.to_sym]
    end

    abitrate = case
    when !Args.noaudio && bitrates[:audio]
      %W(-b:a #{bitrates[:audio]})
      # ['-b:a', bitrates[:audio].to_s]
    end

    afilter = case
    when !Args.noaudio && Config[:defaults][:audiofilter]
      %W(-af #{Config[:defaults][:audiofilter]})
      # ['-af', Config['defaults']['audiofilter']]
    when !Args.noaudio && Args.audiofilter
      %W(-af #{Args.audiofilter})
      # ['-af', Args.audiofilter]
    end
    outcon = case
    when Args.container
      ".#{Args.container}"
    when Config[:defaults][:container]
      ".#{Config[:defaults][:container]}"
    else
      '.mkv'
    end
    # print "#{passmax}\n"
    # @list = [FFmpeg, '-i', filename]
    @list = %W(#{FFmpeg} -i #{filename})
    @list << vcodec
    # @list << %W(-pass #{passnum})
    @list << vbitrate if vbitrate
    # @list << ['-pass', passnum.to_s, '-passlogfile', filepath.sub_ext('').to_s] if passmax == 2
    @list << %W(-pass #{passnum} -passlogfile #{filepath.sub_ext('')}) if passmax == 2
    @list << vcodecopts if vcodecopts
    # @list << ['-filter:v', "fps = #{framerate}"] if framerate
    @list << %W(-filter:v fps=#{framerate}) if framerate
    @list << acodec
    @list << abitrate if abitrate
    @list << acodecopts if acodecopts
    @list << afilter if afilter
    # @list << ['-hide_banner', '-y']
    @list << %w(-hide_banner -y)
    @list << case
    when passnum == 1 && passmax == 2
      # ['-f', 'matroska', '/dev/null']
      %w(-f matroska /dev/null)
    when passnum == 2 && passmax == 2, passmax == 1
      # Args.outputdir.join(filepath.basename.sub_ext(outcon).to_s).to_s
      path = Args.outputdir + filepath.basename.sub_ext(outcon)
      path.to_s
    end
    @list.flatten!
    @list.compact!
  end
end
Args.files.each do |file|
  outcon = case
  when Args.container
    ".#{Args.container}"
  when Config[:defaults][:container]
    ".#{Config[:defaults][:container]}"
  else
    '.mkv'
  end
  filepath = Pathname.new(file)
  # outpath = Pathname.new(Args.outputdir.join(filepath.basename.sub_ext(outcon).to_s).to_s)
  outpath = Args.outputdir + filepath.basename.sub_ext(outcon)
  logpath = filepath.sub_ext('-0.log') if Args.passes == 2
  case Args.passes
  when 2
    cmdpass1 = Command.new(file, 1, 2).list
    cmdpass2 = Command.new(file, 2, 2).list
  when 1
    cmd1pass = Command.new(file, passmax: 1).list
  end
  if Args.debug
    puts cmdpass1 if cmdpass1
    puts cmdpass2 if cmdpass2
    puts cmd1pass if cmd1pass
  end
  begin
    case Args.passes
    when 2 && !Args.debug
      Util::Program.runprogram(cmdpass1)
      Util::Program.runprogram(cmdpass2)
    when 1 && !Args.debug
      Util::Program.runprogram(cmd1pass)
    end
  rescue Subprocess::NonZeroExit => e
    puts Mood.sad('Removing unfinished output file.')
    outpath.delete if outpath.exist?
    raise e
  else
    # Util::Program.runprogram([MkvPropEdit, '--add-track-statistics-tags', outpath.to_s]) if Args.stats
    Util::Program.runprogram(%W(#{MkvPropEdit} --add-track-statistics-tags #{outpath})) if Args.stats
    case
    when !Args.converttest && !Args.debug
      del = GenerateVideoInfo::Videoinfo.all(filename: filepath.basename.to_s)
      deljson = GenerateVideoInfo::Videojson.all(filename: filepath.basename.to_s)
      del.destroy
      deljson.destroy
    end
    puts Mood.happy('In convert testing mode, not deleting database entry') if Args.converttest
  ensure
    logpath.delete if Args.passes == 2 && logpath && logpath.exist? && !Args.debug
  end

  backup(file, Args.backup.to_s) if Args.backup
end
