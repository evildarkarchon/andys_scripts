# frozen_string_literal: true

require 'json'
require 'pathname'

require_relative '../util/recursive_symbolize_keys'
require_relative '../util/findapp'
require_relative '../core/cleanup'

Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Array::Cleanup) : Array.include(AndyCore::Array::Cleanup)

module ABSConvert
  class CmdLine
    attr_reader :list
    def initialize(filename, options, config, verbose: false, passnum:, passmax:)
      @verbose = verbose
      @config = config
      @options = options.to_h
      @filename = filename.to_s
      @filepath = filename.is_a?(Pathname) ? filename.realpath : Pathname.new(filename).realpath
      @passnum = passnum
      @passmax = passmax
    end

    def generate!(bitrates = nil, framerate = nil, exepath = Util::FindApp.which('ffmpeg'))
      raise TypeError, 'bitrates must be a Hash or nil' unless bitrates.is_a?(Hash) || bitrates.nil? || bitrates.respond_to?(:to_h)
      bitrates.to_h unless bitrates.respond_to?(:to_h) && bitrates.is_a?(Hash)
      vcodec =
        case
        when [@options[:novideo], bitrates[:video].nil?].any?
          '-vn'
        when @config[:defaults][:video]
          %W[-c:v #{@config[:defaults][:video]}]
        when @options[:videocodec]
          %W[-c:v #{@options[:videocodec]}]
        end
      vcodec.freeze

      vbitrate =
        case
        when [!@options[:novideo], bitrates[:video]].all?
          %W[-b:v #{bitrates[:video]}]
        end
      vbitrate.freeze

      vcodecopts =
        case
        when !@options[:novideo] && @options[:videocodecopts]
          @options[:videocodecopts]
        when [!@options[:novideo], @options[:videocodec].respond_to?(:to_sym) && @config[:defaults][@options[:videocodec].to_sym]].all?
          @config[:codecs][@options[:videocodec].to_sym]
        end
      vcodecopts.freeze

      acodec =
        case
        when [@passnum == 1 && @passmax == 2, @options[:noaudio], bitrates[:audio].nil?].any?
          '-an'
        when @options[:audiocodec]
          %W[-c:a #{@options[:audiocodec]}]
        when @config[:defaults][:audio]
          %W[-c:a #{@config[:defaults][:audio]}]
        else
          %w[-c:a libopus]
        end
      acodec.freeze

      acodecopts =
        case
        when [!@options[:noaudio], @options[:audiocodecopts]].all?
          @options[:audiocodecopts]
        when [!@options[:noaudio], @options[:audiocodec].respond_to?(:to_sym) && @config[:codecs][@options[:audiocodec].to_sym]].all?
          @config[:codecs][@options[:audiocodec].to_sym]
        end
      acodecopts.freeze

      abitrate =
        case
        when [!@options[:noaudio], bitrates[:audio]].all?
          %W[-b:a #{bitrates[:audio]}]
        end
      abitrate.freeze

      afilter =
        case
        when [!@options[:noaudio], @config[:defaults][:audiofilter]].all?
          %W[-af #{@config[:defaults][:audiofilter]}]
        when [!@options[:noaudio], @options[:audiofilter]].all?
          %W[-af #{@options[:audiofilter]}]
        end
      afilter.freeze

      outcon =
        case
        when @options[:container]
          ".#{@options[:container]}"
        when @config[:defaults][:container]
          ".#{@config[:defaults][:container]}"
        else
          '.mkv'
        end
      outcon.freeze

      @list = %W[#{exepath} -i #{@filename}]
      @list << vcodec
      @list << vbitrate if vbitrate
      @list << %W[-pass #{@passnum} -passlogfile #{@filepath.sub_ext('')}] if @options[:passes] == 2
      @list << vcodecopts if vcodecopts
      @list << %W[-filter:v fps=#{framerate}] if framerate
      @list << acodec
      @list << abitrate if abitrate
      @list << acodecopts if acodecopts
      @list << afilter if afilter
      @list << %w[-hide_banner -y]
      @list << %w[-strict -2] if @options[:audiocodec] == 'opus'
      @list <<
        case
        when @passnum == 1 && @passmax == 2
          # ['-f', 'matroska', '/dev/null']
          %w[-f matroska /dev/null]
        when @passnum == 2 && @passmax == 2, @passmax == 1
          # @options[:outputdir].join(filepath.basename.sub_ext(outcon).to_s).to_s
          @options[:outputdir].joinpath(@filepath.basename.sub_ext(outcon)).to_s
        end
      @list.cleanup!(unique: false)
      @list.freeze
    end

    def inspect
      "<ABSConvert::CmdLine @list = #{@list}>"
    end
  end
end
