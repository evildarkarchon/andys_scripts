# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'shellwords'
require 'json'

require_relative '../util/recursive_symbolize_keys'

module ABSConvert
  class Options
    attr_reader :files, :args, :config, :paths

    def initialize(args)
      @args = {}
      @args[:novideo] = false
      @args[:noaudio] = false
      @args[:videocodec] = 'libvpx-vp9'
      @args[:audiocodec] = 'libopus'
      @args[:videocodecopts] = nil
      @args[:audiocodecopts] = nil
      @args[:videobitrate] = nil
      @args[:audiobitrate] = nil
      @args[:db] = Pathname.getwd.join('videoinfo.sqlite')
      @args[:audiofilter] = nil
      @args[:passes] = 2
      @args[:converttest] = false
      @args[:debug] = false
      @args[:config] = Pathname.new(Dir.home).join('.config/absconvert.json')
      @args[:stats] = true
      @args[:stats] = true
      @args[:container] = nil
      @args[:backup] = nil
      @args[:framerate] = nil
      @args[:outputdir] =
        case
        when Dir.pwd.include?('videoutiltest')
          Pathname.getwd
        when Dir.pwd == Dir.home
          Pathname.new(Dir.home)
        else
          Pathname.getwd.parent
        end
      @args[:verbose] = false
      @sourceargs = args
    end

    def parse_args!
      optparse = OptionParser.new do |opts|
        opts.on('--no-video', "Don't encode video stream") do
          @args[:novideo] = true
          @args[:videocodec] = nil
        end
        opts.on('--video-codec [codec]', 'Video codec to use to encode the video stream') do |i|
          novideo = %w[none None].any? { |a| a == i }
          @args[:novideo] = true if novideo
          @args[:videocodec] = novideo ? nil : i
        end
        opts.on('--frame-rate [framerate]', '-f', 'Frame rate for the video stream') { |i| @args[:framerate] = i }
        opts.on('--video-bitrate [bitrate]', 'Bitrate for the video stream') { |i| @args[:videobitrate] = i }
        opts.on('--video-codec-opts [opts]', 'Options for the video codec') { |i| options[:videocodecopts] = i.shellsplit }
        opts.on('--passes [passes]', 'Number of passes for the video encoding') do |i|
          valid = [1, 2].any? { |a| a == i.to_i }
          @args[:passes] = i.to_i if valid
          @args[:passes] = 2 if i.to_i > 2
          @args[:passes] = 1 if i.to_i < 1
        end

        opts.on('--no-audio', "Don't encode audio stream") do
          @args[:noaudio] = true
          @args[:audiocodec] = nil
        end
        opts.on('--audio-codec [codec]', 'Audio codec to use to encode the audio stream') do |i|
          noaudio = %w[none None].any? { |a| a == i }
          @args[:audiocodec] = nil if noaudio
          @args[:noaudio] = true if noaudio
          @args[:audiocodec] = i unless noaudio
        end
        opts.on('--audio-bitrate [bitrate]', 'Bitrate for the audio stream') { |i| @args[:audiobitrate] = i }
        opts.on('--audio-codec-opts [opts]', 'Options for the audio codec') { |i| @args[:audiocodecopts] = i.shellsplit }
        opts.on('--audio-filter [filter]', 'Filter to be used on the output audio') { |i| @args[:audiofilter] = i }

        opts.on('--database [location]', 'Location of the videoinfo database') { |i| @args[:db] = i }
        opts.on('--convert-test', "Don't delete any videoinfo entries") { @args[:converttest] = true }
        opts.on('--config [path]', '-c [path]', 'Location of the configuration json file.') { |i| @args[:config] = Pathname.new(i) }
        opts.on('--container [ext]', 'Container to be used on the output file (do not include the dot).') { |i| @args[:container] = ".#{i}" }
        opts.on('--no-sort', "Don't sort the file list") { @args[:sort] = false }
        opts.on('--no-stats', "Don't calculate statistics tags for the output file.") { @args[:stats] = false }
        opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |i| options[:backup] = Pathname.new(i) }
        opts.on('--output [dir]', '-o [dir]', 'Location of the output directory.') { |i| options[:outputdir] = i }
        opts.on('--verbose', '-v', 'Make the script a bit more chatty.') { @args[:verbose] = true }
        opts.on('--debug', '-d', 'Print variables and method states and exit') do
          @args[:debug] = true
          @args[:verbose] = true
        end
      end

      optparse.parse!(@sourceargs)

      vp9default = %w[-threads 4 -tile-columns 2 -frame-parallel 1 -speed 1]
      vp8default = %w[-threads 4 -speed 1]
      @args[:videocodecopts] = [@args[:videocodec] == 'libvpx-vp9', !@args[:videocodecopts]].all? ? vp9default : @args[:videocodecopts]
      @args[:videocodecopts] = [@args[:videocodec] == 'libvpx', !@args[:videocodecopts]].all? ? vp8default : @args[:videocodecopts]
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
        puts config.inspect if @args[:debug] && @config
        @config.freeze
      end
    end

    def [](key)
      hash = { files: @files, args: @args, config: @config, paths: @paths }
      hash[key]
    end

    def to_h
      { files: @files, args: @args, config: @config, paths: @paths }
    end
  end
end
