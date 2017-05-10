# frozen_string_literal: true

require 'pathname'
require 'optparse'
module YTDL
  class Options
    attr_reader :args, :urls
    def initialize(sourceargs)
      @args = {}
      @args[:directory] = Pathname.new('/data/Videos/Youtube')
      @args[:subdirectory] = nil
      @args[:datesubdir] = true
      @args[:force] = false
      @args[:pretend] = false
      @args[:stats] = true
      @args[:archive] = nil
      @args[:no_download] = false
      # @args[:mux] = false
      # @args[:config] = Pathname.new(Dir.home) + '.config/convertmkv.json'
      @args[:keep_original] = false
      @args[:keep_split] = false
      @args[:ffmpegdl] = false
      @args[:webm] = false
      @args[:playlist] = true
      @args[:playlistpath] = nil
      @args[:resetplaylist] = false
      @args[:no_blacklist] = false
      @args[:sort] = true
      @args[:drive_letter] = nil
      @args[:test_download] = false
      @args[:mux] = false
      @args[:ffmpegmux] = false
      @sourceargs = sourceargs
    end

    def parse_args!
      optparse = OptionParser.new do |opts|
        opts.on('-d', '--directory [DIRECTORY]', 'Name of the directory to download to') { |dir| @args[:directory] = Pathname.new(dir) }
        opts.on('-a', '--archive [DIRECTORY]', 'Directory for the downloaded video list') { |dir| @args[:archive] = Pathname.new(dir) }
        opts.on('-s', '--subdirectory [SUBDIRECTORY]', 'Optional subdirectory to tack on the end (only used if directory is set to the default)') { |dir| @args[:subdirectory] = dir.to_s.freeze }
        opts.on('-n', '--no-date', "Don't create a subdirectory with the date (only needed if directory is set to the default)") { @args[:datesubdir] = false }
        opts.on('-f', '--force', "Don't add the url(s) to the list of succesfully downloaded videos or read from said list.") { @args[:force] = true }
        opts.on('-p', '--pretend', "Don't actually run youtube-dl or mkvpropedit") { @args[:pretend] = true } # Mostly for testing code that doesn't rely on the programs actually running.
        opts.on('--no-download', "Run operations that don't require downloading.") { @args[:no_download] = true }
        opts.on('--no-stats', "Don't calculate statistics for MKV files.") { @args[:stats] = false }
        opts.on('--webm', 'use webm instead of mkv for merging files (videos that have separate files per stream).') { @args[:webm] = true }
        # opts.on('-m', '--mux', 'mux non-mkv files') { @args[:mux] = true }
        # opts.on('--convertmkv-config', 'Location for the convertmkv configuration file.') { |c| @args[:config] = c } # Reusing the convertmkv config file since the @args used are the same.
        opts.on('--mux-mkv', 'Mux any non-mkv files to mkv') { @args[:mux] = true }
        opts.on('--ffmpeg-mux', 'Use ffmpeg instead of mkvmerge for muxing mkv files (warning: ffmpeg hates mpeg2-ps files)') { @args[:ffmpegmux] = true }
        opts.on('-k', '--keep-original', 'Keep the original file if muxing non-mkv files.') { @args[:keep_original] = true }
        opts.on('-ks', '--keep-split', 'Keep the original split download files (if there are any)') do
          @args[:keep_split] = true
          @args[:no_mux] = true
        end
        opts.on('--ffmpeg-download', 'Download using ffmpeg') { @args[:ffmpegdl] = true } # hoping this will fix certain video downloads
        opts.on('--no-playlist', "Don't create a playlist") { @args[:playlist] = false }
        opts.on('--playlist-path [FILE]', 'Location to save the playlist') { |i| @args[:playlistpath] = Pathname.new(i) }
        opts.on('--reset-playlist', 'Do not modify an existing playlist (if it exists)') { @args[:resetplaylist] = true }
        opts.on('--no-blacklist', 'Do not put downloaded files in the playlist blacklist.') { @args[:no_blacklist] = true }
        opts.on('--no-sort', 'Do not run any sorting operations.') { @args[:sort] = false }
        opts.on('--drive-letter [LETTER]', 'Drive letter to use for the xspf playlist (not used if directory is set to default)') { |i| @args[:drive_letter] = i }
        opts.on('--test-download', 'Test the download function, remove any downloaded files imediatley after download') do
          @args[:test_download] = true
          @args[:playlist] = false
          @args[:no_blacklist] = true
          @args[:force] = true
        end
      end
      optparse.parse!(@sourceargs)
    end

    def parse_urls!
      @urls = @sourceargs.dup
      @urls.keep_if { |url| url.is_a?(String) }
      @urls.keep_if { |url| url =~ /\A#{URI.regexp(%w[http https])}\z/ }
    end
  end
end
