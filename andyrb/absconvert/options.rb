# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'shellwords'
require 'json'

require_relative '../util/recursive_symbolize_keys'

class Options
  attr_reader :files, :options, :config, :paths

  def initialize(args)
    @options = {}
    @options[:novideo] = false
    @options[:noaudio] = false
    @options[:videocodec] = 'libvpx-vp9'
    @options[:audiocodec] = 'libopus'
    @options[:videocodecopts] = nil
    @options[:audiocodecopts] = nil
    @options[:videobitrate] = nil
    @options[:audiobitrate] = nil
    @options[:db] = Pathname.getwd.join('videoinfo.sqlite')
    @options[:audiofilter] = nil
    @options[:passes] = 2
    @options[:converttest] = false
    @options[:debug] = false
    @options[:config] = Pathname.new(Dir.home).join('.config/absconvert.json')
    @options[:stats] = true
    @options[:stats] = true
    @options[:container] = nil
    @options[:backup] = nil
    @options[:framerate] = nil
    @options[:outputdir] =
      case
      when Dir.pwd.include?('videoutiltest')
        Pathname.getwd
      when Dir.pwd == Dir.home
        Pathname.new(Dir.home)
      else
        Pathname.getwd.parent
      end
    @options[:verbose] = false
    @args = args
  end

  def parse_args!
    optparse = OptionParser.new do |opts|
      opts.on('--no-video', "Don't encode video stream") do
        @options[:novideo] = true
        @options[:videocodec] = nil
      end
      opts.on('--video-codec [codec]', 'Video codec to use to encode the video stream') do |i|
        novideo = %w[none None].any? { |a| a == i }
        @options[:novideo] = true if novideo
        @options[:videocodec] = !novideo ? i : nil
      end
      opts.on('--frame-rate [framerate]', '-f', 'Frame rate for the video stream') { |i| @options[:framerate] = i }
      opts.on('--video-bitrate [bitrate]', 'Bitrate for the video stream') { |i| @options[:videobitrate] = i }
      opts.on('--video-codec-opts [opts]', 'Options for the video codec') { |i| options[:videocodecopts] = i.shellsplit }
      opts.on('--passes [passes]', 'Number of passes for the video encoding') do |i|
        valid = [1, 2].any? { |a| a == i.to_i }
        @options[:passes] = i.to_i if valid
        @options[:passes] = 2 if i.to_i > 2
        @options[:passes] = 1 if i.to_i < 1
      end

      opts.on('--no-audio', "Don't encode audio stream") do
        @options[:noaudio] = true
        @options[:audiocodec] = nil
      end
      opts.on('--audio-codec [codec]', 'Audio codec to use to encode the audio stream') do |i|
        noaudio = %w[none None].any? { |a| a == i }
        @options[:audiocodec] = nil if noaudio
        @options[:noaudio] = true if noaudio
        @options[:audiocodec] = i unless noaudio
      end
      opts.on('--audio-bitrate [bitrate]', 'Bitrate for the audio stream') { |i| @options[:audiobitrate] = i }
      opts.on('--audio-codec-opts [opts]', 'Options for the audio codec') { |i| @options[:audiocodecopts] = i.shellsplit }
      opts.on('--audio-filter [filter]', 'Filter to be used on the output audio') { |i| @options[:audiofilter] = i }

      opts.on('--database [location]', 'Location of the videoinfo database') { |i| @options[:db] = i }
      opts.on('--convert-test', "Don't delete any videoinfo entries") { @options[:converttest] = true }
      opts.on('--config [path]', '-c [path]', 'Location of the configuration json file.') { |i| @options[:config] = Pathname.new(i) }
      opts.on('--container [ext]', 'Container to be used on the output file (do not include the dot).') { |i| @options[:container] = ".#{i}" }
      opts.on('--no-sort', "Don't sort the file list") { @options[:sort] = false }
      opts.on('--no-stats', "Don't calculate statistics tags for the output file.") { @options[:stats] = false }
      opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |i| options[:backup] = Pathname.new(i) }
      opts.on('--output [dir]', '-o [dir]', 'Location of the output directory.') { |i| options[:outputdir] = i }
      opts.on('--verbose', '-v', 'Make the script a bit more chatty.') { @options[:verbose] = true }
      opts.on('--debug', '-d', 'Print variables and method states and exit') do
        @options[:debug] = true
        @options[:verbose] = true
      end
    end

    optparse.parse!(@args)

    vp9default = %w[-threads 4 -tile-columns 2 -frame-parallel 1 -speed 1]
    vp8default = %w[-threads 4 -speed 1]
    @options[:videocodecopts] = [@options[:videocodec] == 'libvpx-vp9', !@options[:videocodecopts]].all? ? vp9default : @options[:videocodecopts]
    @options[:videocodecopts] = [@options[:videocodec] == 'libvpx', !@options[:videocodecopts]].all? ? vp8default : @options[:videocodecopts]
  end

  def parse_files!
    @files = @args.dup
    @files.keep_if { |i| File.file?(i) } if @files.respond_to?(:keep_if)
    @paths = @files.map { |i| Pathname.new(i) }
  end

  def parse_config!
    @config = nil
    if options[:config].exist? # rubocop:disable Style/GuardClause
      options[:config].open do |cf|
        @config = JSON.parse(cf.read)
      end
      @config = Util.recursive_symbolize_keys(@config)
      puts config.inspect if @options[:debug] && @config
      @config.freeze
    end
  end
end
