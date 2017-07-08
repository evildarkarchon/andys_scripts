# frozen_string_literal: true

require 'pathname'
require 'optparse'

require 'addressable/uri'

require_relative '../options'
module YTDL
  class YtOptions < Options
    attr_reader :args, :urls
    def initialize(sourceargs)
      now = Time.now.strftime('%Y%m%d')
      defaultargs = {}
      defaultargs[:directory] = Pathname.new('/data/Videos/Youtube')
      defaultargs[:subdirectory] = nil
      defaultargs[:datesubdir] = true
      defaultargs[:force] = false
      defaultargs[:pretend] = false
      defaultargs[:stats] = true
      defaultargs[:archive] = nil
      defaultargs[:no_download] = false
      defaultargs[:keep_original] = false
      defaultargs[:keep_split] = false
      defaultargs[:ffmpegdl] = false
      defaultargs[:webm] = false
      defaultargs[:playlist] = true
      defaultargs[:playlistpath] = Pathname.new("/data/Youtube/Videos/#{now}/#{now}.xspf")
      defaultargs[:resetplaylist] = false
      defaultargs[:no_blacklist] = false
      defaultargs[:sort] = true
      defaultargs[:drive_letter] = nil
      defaultargs[:test_download] = false
      defaultargs[:mux] = false
      defaultargs[:ffmpegmux] = false
      super(sourceargs, defaultargs)
    end

    def parse_args!
      super do |o, k|
        o.on('-d', '--directory [DIRECTORY]', 'Name of the directory to download to') { |dir| k[:directory] = Pathname.new(dir) }
        o.on('-a', '--archive [DIRECTORY]', 'Directory for the downloaded video list') { |dir| k[:archive] = Pathname.new(dir) }
        o.on('-s', '--subdirectory [SUBDIRECTORY]', 'Optional subdirectory to tack on the end (only used if directory is set to the default)') { |dir| k[:subdirectory] = dir.to_s.freeze }
        o.on('-n', '--no-date', "Don't create a subdirectory with the date (only needed if directory is set to the default)") { k[:datesubdir] = false }
        o.on('-f', '--force', "Don't add the url(s) to the list of succesfully downloaded videos or read from said list.") { k[:force] = true }
        o.on('-p', '--pretend', "Don't actually run youtube-dl or mkvpropedit") { k[:pretend] = true } # Mostly for testing code that doesn't rely on the programs actually running.
        o.on('--no-download', "Run operations that don't require downloading.") { k[:no_download] = true }
        o.on('--no-stats', "Don't calculate statistics for MKV files.") { k[:stats] = false }
        o.on('--webm', 'use webm instead of mkv for merging files (videos that have separate files per stream).') { k[:webm] = true }
        o.on('--mux-mkv', 'Mux any non-mkv files to mkv') { k[:mux] = true }
        o.on('--ffmpeg-mux', 'Use ffmpeg instead of mkvmerge for muxing mkv files (warning: ffmpeg hates mpeg2-ps files)') { k[:ffmpegmux] = true }
        o.on('-k', '--keep-original', 'Keep the original file if muxing non-mkv files.') { k[:keep_original] = true }
        o.on('-ks', '--keep-split', 'Keep the original split download files (if there are any)') do
          k[:keep_split] = true
          k[:no_mux] = true
        end
        o.on('--ffmpeg-download', 'Download using ffmpeg') { k[:ffmpegdl] = true } # hoping this will fix certain video downloads
        o.on('--no-playlist', "Don't create a playlist") { k[:playlist] = false }
        o.on('--playlist-path [FILE]', 'Location to save the playlist') { |i| k[:playlistpath] = Pathname.new(i) }
        o.on('--reset-playlist', 'Do not modify an existing playlist (if it exists)') { k[:resetplaylist] = true }
        o.on('--no-blacklist', 'Do not put downloaded files in the playlist blacklist.') { k[:no_blacklist] = true }
        o.on('--no-sort', 'Do not run any sorting operations.') { k[:sort] = false }
        o.on('--drive-letter [LETTER]', 'Drive letter to use for the xspf playlist (not used if directory is set to default)') { |i| k[:drive_letter] = i }
        o.on('--test-download', 'Test the download function, remove any downloaded files imediatley after download') do
          k[:test_download] = true
          k[:playlist] = false
          k[:no_blacklist] = true
          k[:force] = true
        end
      end
    end

    def parse_urls!
      @urls = @source.dup
      @urls.keep_if { |url| url.is_a?(String) }
      # @urls.keep_if { |url| url =~ /\A#{URI.regexp(%w[http https])}\z/ }
      @urls.keep_if do |url|
        parsed = Addressable::URI.parse(url).normalize
        %w[http https].include?(parsed.scheme)
      end
    end

    def [](key)
      hash = { source: @source, args: @args, urls: @urls }
      hash[key]
    end

    def inspect
      "Options<@source = #{@source}, @args = #{@args}, @urls = #{@urls}>"
    end

    def to_h
      { source: @source, args: @args, urls: @urls }
    end
  end
end
