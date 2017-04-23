# frozen_string_literal: true

require 'pathname'
require 'optparse'

class Options
  attr_reader :options, :urls
  def initialize(args)
    @options = {}
    @options[:directory] = Pathname.new('/data/Videos/Youtube')
    @options[:subdirectory] = nil
    @options[:datesubdir] = true
    @options[:force] = false
    @options[:pretend] = false
    @options[:stats] = true
    @options[:archive] = nil
    @options[:no_download] = false
    # @options[:mux] = false
    # @options[:config] = Pathname.new(Dir.home) + '.config/convertmkv.json'
    @options[:keep_original] = false
    @options[:keep_split] = false
    @options[:ffmpegdl] = false
    @options[:webm] = false
    @options[:playlist] = true
    @options[:playlistpath] = nil
    @options[:resetplaylist] = false
    @options[:no_blacklist] = false
    @options[:sort] = true
    @options[:drive_letter] = nil
    @options[:test_download] = false
    @args = args
  end

  def parse_args!
    optparse = OptionParser.new do |opts|
      opts.on('-d', '--directory [DIRECTORY]', 'Name of the directory to download to') { |dir| @options[:directory] = Pathname.new(dir) }
      opts.on('-a', '--archive [DIRECTORY]', 'Directory for the downloaded video list') { |dir| @options[:archive] = Pathname.new(dir) }
      opts.on('-s', '--subdirectory [SUBDIRECTORY]', 'Optional subdirectory to tack on the end (only used if directory is set to the default)') { |dir| @options[:subdirectory] = dir.to_s.freeze }
      opts.on('-n', '--no-date', "Don't create a subdirectory with the date (only needed if directory is set to the default)") { @options[:datesubdir] = false }
      opts.on('-f', '--force', "Don't add the url(s) to the list of succesfully downloaded videos or read from said list.") { @options[:force] = true }
      opts.on('-p', '--pretend', "Don't actually run youtube-dl or mkvpropedit") { @options[:pretend] = true } # Mostly for testing code that doesn't rely on the programs actually running.
      opts.on('--no-download', "Run operations that don't require downloading.") { @options[:no_download] = true }
      opts.on('--no-stats', "Don't calculate statistics for MKV files.") { @options[:stats] = false }
      opts.on('--webm', 'use webm instead of mkv for merging files (videos that have separate files per stream).') { @options[:webm] = true }
      # opts.on('-m', '--mux', 'mux non-mkv files') { @options[:mux] = true }
      # opts.on('--convertmkv-config', 'Location for the convertmkv configuration file.') { |c| @options[:config] = c } # Reusing the convertmkv config file since the @options used are the same.
      opts.on('-k', '--keep-original', 'Keep the original file if muxing non-mkv files.') { @options[:keep_original] = true }
      opts.on('-ks', '--keep-split', 'Keep the original split download files (if there are any)') do
        @options[:keep_split] = true
        @options[:no_mux] = true
      end
      opts.on('--ffmpeg-download', 'Download using ffmpeg') { @options[:ffmpegdl] = true } # hoping this will fix certain video downloads
      opts.on('--no-playlist', "Don't create a playlist") { @options[:playlist] = false }
      opts.on('--playlist-path [FILE]', 'Location to save the playlist') { |i| @options[:playlistpath] = Pathname.new(i) }
      opts.on('--reset-playlist', 'Do not modify an existing playlist (if it exists)') { @options[:resetplaylist] = true }
      opts.on('--no-blacklist', 'Do not put downloaded files in the playlist blacklist.') { @options[:no_blacklist] = true }
      opts.on('--no-sort', 'Do not run any sorting operations.') { @options[:sort] = false }
      opts.on('--drive-letter [LETTER]', 'Drive letter to use for the xspf playlist (not used if directory is set to default)') { |i| @options[:drive_letter] = i }
      opts.on('--test-download', 'Test the download function, remove any downloaded files imediatley after download') do
        @options[:test_download] = true
        @options[:playlist] = false
        @options[:no_blacklist] = true
        @options[:force] = true
      end
    end
    optparse.parse!(@args)
  end

  def parse_urls!
    @urls = @args.dup
    @urls.keep_if { |url| url.is_a?(String) }
    @urls.keep_if { |url| url =~ /\A#{URI.regexp(%w[http https])}\z/ }
  end
end
