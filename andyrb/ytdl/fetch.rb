# frozen_string_literal: true

require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../util/sort'
require_relative '../mood'
require_relative '../core/cleanup'

Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include

module YTDL
  class Fetch
    attr_reader :filenames, :date, :directory, :subdirectory
    def initialize(directory, urls, sort: true, pretend: false, subdirectory: nil, date: true)
      @date = Time.now.strftime('%Y%m%d').freeze
      @datesubdir = date
      @subdirectory = subdirectory.to_s
      @directory = directory.instance_of?(Pathname) ? directory : Pathname.new(directory)
      @directory += @date if date
      @directory += @subdirectory if @subdirectory
      @urls = urls
      @sort = sort
      @pretend = pretend
    end

    def fetch_filenames!
      @filenames = []
      print(Mood.happy { 'Retrieving filenames for videos to be downloaded... ' })
      Util::FindApp.which('youtube-dl') do |yt|
        Urls.each { |url| @filenames << Util::Program.runprogram(%W[#{yt} --get-filename #{url}], parse_output: true) }
      end
      puts 'done.'
      @filenames.cleanup!
      @filenames.map! { |i| @directory.join(i).to_s }
      @filenames.map!(&:strip)
      @filenames = Util.sort(files) if @sort
    end

    def archive(archivedir = nil)
      archdir = @directory.parent.parent.freeze if [@subdirectory, @directory.to_s.include?('/data/Videos/Youtube'), @datesubdir].all?

      archive =
        case
        when archivedir
          puts(Mood.neutral { 'Archive from command line' }) if Args.pretend
          archivedir + 'downloaded.txt'
        when [@datesubdir, archdir].all?
          puts(Mood.neutral { 'Archive in subdirectory parent' }) if Args.pretend
          archdir + 'downloaded.txt'
        when [@datesubdir, @directory.to_s.include?('/data/Videos/Youtube')].all?
          puts(Mood.neutral { 'Archive in parent directory' }) if Args.pretend
          @directory.parent + 'downloaded.txt'
        else
          puts(Mood.neutral { 'Archive in download directory' }) if Args.pretend
          @directory + 'downloaded.txt'
        end
      archive.freeze
      puts(Mood.neutral { archive }) if Args.pretend
      archive
    end

    def fetch_videos(webmout: false, force: false, keep_split: false, ffmpegdl: false)
      Util::FindApp.which('youtube-dl') do |yt|
        ytdl = %W[#{yt}]
        ytdl << %W[--download-archive #{archive}] unless force
        ytdl << %w[--merge-output-format webm] if webmout
        ytdl << '-k' if keep_split
        ytdl << %w[--hls-prefer-ffmpeg --external-downloader ffmpeg --external-downloader-args -hide_banner] if ffmpegdl
        ytdl << @urls
        ytdl.cleanup!(unique: false)
        ytdl.freeze

        Util::Program.runprogram(ytdl, workdir: @directory) unless @pretend
        puts ytdl.inspect if @pretend
      end
    end
  end
end
