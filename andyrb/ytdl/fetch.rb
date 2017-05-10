# frozen_string_literal: true

require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../core/sort'
require_relative '../mood'
require_relative '../core/cleanup'
require_relative '../core/monkeypatch'

# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)
AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)
AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

module YTDL
  class Fetch
    attr_reader :filenames, :date, :directory, :subdirectory, :filepaths
    def initialize(directory, urls, sort: true, pretend: false, subdirectory: nil, datesubdir: true, nodownload: false)
      @date = Time.now.strftime('%Y%m%d').freeze
      @datesubdir = datesubdir
      @subdirectory = subdirectory.to_s
      @directory = directory.instance_of?(Pathname) ? directory : Pathname.new(directory)
      @directory += @date if datesubdir
      @directory += @subdirectory if @subdirectory
      puts(Mood.happy { "Creating Directory #{@directory}" }) unless @directory.exist?
      @directory.mkpath unless @directory.exist?
      @urls = urls
      @sort = sort
      @pretend = pretend
      @archive = nil
      @nodownload = nodownload
      @filepaths = []
    end

    def fetch_filenames!
      @filenames = []
      print(Mood.happy { 'Retrieving filenames for videos to be downloaded... ' })
      Util::FindApp.which('youtube-dl') do |yt|
        @urls.each { |url| @filenames << Util::Program.runprogram(%W[#{yt} --get-filename #{url}], parse_output: true).split("\n") }
      end
      # puts @filenames.inspect
      puts 'done.'
      # puts 'deleting is not necessary' unless @filenames.to_s.include?("\n")
      @filenames.cleanup!
      # splitfilenames = @filenames.map { |e| e.split("\n") if !e.nil? && e.include?("\n") }
      # splitfilenames.cleanup!(unique: false)
      # @filenames += splitfilenames unless splitfilenames.empty?
      # @filenames.delete_if { |i| i.include?("\n") }
      @filenames.map!(&:strip)
      @filenames.map! { |i| @directory.join(i).to_s }
      @filenames.natsort! if @sort
      @filepaths = @filenames.map { |i| Pathname.new(i) } unless @filenames.empty?
      puts Mood.neutral('Derived Filenames:') if @pretend
      puts @filenames.inspect if @pretend
      puts @filepaths.inspect if @pretend
    end

    def setarchive!(archivedir = nil)
      archdir = @directory.parent.parent.freeze if [@subdirectory, @directory.to_s.include?('/data/Videos/Youtube'), @datesubdir].all?

      archive =
        case
        when archivedir
          puts(Mood.neutral { 'Archive from command line' }) if @pretend
          archivedir + 'downloaded.txt'
        when [@datesubdir, archdir].all?
          puts(Mood.neutral { 'Archive in subdirectory parent' }) if @pretend
          archdir + 'downloaded.txt'
        when [@datesubdir, @directory.to_s.include?('/data/Videos/Youtube')].all?
          puts(Mood.neutral { 'Archive in parent directory' }) if @pretend
          @directory.parent + 'downloaded.txt'
        else
          puts(Mood.neutral { 'Archive in download directory' }) if @pretend
          @directory + 'downloaded.txt'
        end
      archive.freeze
      puts(Mood.neutral { archive }) if [@pretend, !@nodownload].all?
      @archive = archive
    end

    def fetch_videos(webmout: false, force: false, keep_split: false, ffmpegdl: false)
      Util::FindApp.which('youtube-dl') do |yt|
        ytdl = %W[#{yt}]
        ytdl << %W[--download-archive #{@archive}] unless force || @nodownload
        ytdl << %w[--merge-output-format webm] if webmout
        ytdl << '-k' if keep_split
        ytdl << %w[--hls-prefer-ffmpeg --external-downloader ffmpeg --external-downloader-args -hide_banner] if ffmpegdl
        ytdl << @urls
        ytdl.cleanup!(unique: false)
        ytdl.freeze

        Util::Program.runprogram(ytdl, workdir: @directory) unless [@pretend, @nodownload].any?
        puts ytdl.inspect if @pretend && !@nodownload
      end
    end

    def inspect
      "YTDL::Fetch<@date = #{@date}, @datesubdir = #{@datesubdir}, @subdirectory = #{@subdirectory}, @directory = #{@directory}, @urls = #{@urls}, @sort = #{@sort}, @pretend = #{@pretend}, @archive = #{@archive}, @nodownload = #{@nodownload}, @filepaths = #{@filepaths}>"
    end
  end
end
