# frozen_string_literal: true

require 'pathname'
require 'shellwords'
require 'json'

require_relative '../util/recursive_symbolize_keys'
require_relative '../util/media_file'
require_relative '../options'

module ABSConvert
  class Config < Options
    attr_reader :config, :paths
    def initialize(source)
      defaultopts = {}
      defaultopts[:novideo] = false
      defaultopts[:noaudio] = false
      defaultopts[:videocodec] = 'libvpx-vp9'
      defaultopts[:audiocodec] = 'libopus'
      defaultopts[:videocodecopts] = %w[-threads 4 -tile-columns 2 -frame-parallel 1 -speed 1]
      defaultopts[:audiocodecopts] = nil
      defaultopts[:videobitrate] = nil
      defaultopts[:audiobitrate] = nil
      defaultopts[:db] = Pathname.getwd.join('videoinfo.sqlite')
      defaultopts[:audiofilter] = nil
      defaultopts[:passes] = 2
      defaultopts[:converttest] = false
      defaultopts[:debug] = false
      defaultopts[:config] = Pathname.new(Dir.home).join('.config/absconvert.json')
      defaultopts[:stats] = true
      defaultopts[:stats] = true
      defaultopts[:container] = nil
      defaultopts[:backup] = nil
      defaultopts[:framerate] = nil
      defaultopts[:outputdir] =
        case
        when Dir.pwd.include?('videoutiltest')
          Pathname.getwd
        when Dir.pwd == Dir.home
          Pathname.new(Dir.home)
        else
          Pathname.getwd.parent
        end
      defaultopts[:verbose] = false
      super(source, defaultopts)
    end

    def parse_args!
      # First experiment with super methods (from absconvert/options2.rb)
      super do |o, k|
        o.on('--no-video', "Don't encode video stream") do
          k[:novideo] = true
          k[:videocodec] = nil
        end
        o.on('--video-codec [codec]', 'Video codec to use to encode the video stream') do |i|
          novideo = %w[none None].any? { |a| a == i }
          k[:novideo] = true if novideo
          k[:videocodec] = novideo ? nil : i
        end
        o.on('--frame-rate [framerate]', '-f', 'Frame rate for the video stream') { |i| k[:framerate] = i }
        o.on('--video-bitrate [bitrate]', 'Bitrate for the video stream') { |i| k[:videobitrate] = i }
        o.on('--video-codec-opts [opts]', 'Options for the video codec') { |i| k[:videocodecopts] = i.shellsplit }
        o.on('--passes [passes]', 'Number of passes for the video encoding') do |i|
          valid = [1, 2].any? { |a| a == i.to_i }
          k[:passes] = i.to_i if valid
          k[:passes] = 2 if i.to_i > 2
          k[:passes] = 1 if i.to_i < 1
        end

        o.on('--no-audio', "Don't encode audio stream") do
          k[:noaudio] = true
          k[:audiocodec] = nil
        end
        o.on('--audio-codec [codec]', 'Audio codec to use to encode the audio stream') do |i|
          noaudio = %w[none None].any? { |a| a == i }
          k[:audiocodec] = nil if noaudio
          k[:noaudio] = true if noaudio
          k[:audiocodec] = i unless noaudio
        end
        o.on('--audio-bitrate [bitrate]', 'Bitrate for the audio stream') { |i| k[:audiobitrate] = i }
        o.on('--audio-codec-opts [opts]', 'Options for the audio codec') { |i| k[:audiocodec] = i.shellsplit }
        o.on('--audio-filter [filter]', 'Filter to be used on the output audio') { |i| k[:audiofilter] = i }

        o.on('--database [location]', 'Location of the videoinfo database') { |i| k[:db] = i }
        o.on('--convert-test', "Don't delete any videoinfo entries") { k[:converttest] = true }
        o.on('--config [path]', '-c [path]', 'Location of the configuration json file.') { |i| k[:config] = Pathname.new(i) }
        o.on('--container [ext]', 'Container to be used on the output file (do not include the dot).') { |i| k[:container] = ".#{i}" }
        o.on('--no-sort', "Don't sort the file list") { k[:sort] = false }
        o.on('--no-stats', "Don't calculate statistics tags for the output file.") { k[:stats] = false }
        o.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |i| k[:backup] = Pathname.new(i) }
        o.on('--output [dir]', '-o [dir]', 'Location of the output directory.') { |i| k[:outputdir] = i }
        o.on('--verbose', '-v', 'Make the script a bit more chatty.') { k[:verbose] = true }
        o.on('--debug', '-d', 'Print variables and method states and exit') do
          k[:debug] = true
          k[:verbose] = true
        end
      end
    end

    def parse_files!
      files = @source.dup
      files.keep_if { |i| Util.media_file?(i) } if files.respond_to?(:keep_if)
      @paths = files.map { |i| Pathname.new(i) }
    end

    def parse_config!
      @config = nil
      if @args[:config].exist? # rubocop:disable Style/GuardClause
        @args[:config].open do |cf|
          @config = JSON.parse(cf.read)
        end
        @config = Util.recursive_symbolize_keys(@config).freeze
        p @config if @args[:debug] && @config
      end
    end
  end
end
