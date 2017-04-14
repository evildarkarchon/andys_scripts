#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'

require_relative 'andyrb/ytdl'

class Options
  def self.parse(args)
    args.cleanup!
    options = OpenStruct.new
    options.directory = Pathname.new('/data/Videos/Youtube')
    options.subdirectory = nil
    options.datesubdir = true
    options.force = false
    options.pretend = false
    options.stats = true
    options.archive = nil
    options.no_download = false
    # options.mux = false
    # options.config = Pathname.new(Dir.home) + '.config/convertmkv.json'
    options.keep_original = false
    options.keep_split = false
    options.ffmpegdl = false
    options.webm = false
    options.playlist = true
    options.playlistpath = nil
    options.resetplaylist = false
    options.no_blacklist = false
    options.sort = true
    options.drive_letter = nil

    optparse = OptionParser.new do |opts|
      opts.on('-d', '--directory [DIRECTORY]', 'Name of the directory to download to') { |dir| options.directory = Pathname.new(dir) }
      opts.on('-a', '--archive [DIRECTORY]', 'Directory for the downloaded video list') { |dir| options.archive = Pathname.new(dir) }
      opts.on('-s', '--subdirectory [SUBDIRECTORY]', 'Optional subdirectory to tack on the end (only used if directory is set to the default)') { |dir| options.subdirectory = dir.to_s.freeze }
      opts.on('-n', '--no-date', "Don't create a subdirectory with the date (only needed if directory is set to the default)") { options.datesubdir = false }
      opts.on('-f', '--force', "Don't add the url(s) to the list of succesfully downloaded videos or read from said list.") { options.force = true }
      opts.on('-p', '--pretend', "Don't actually run youtube-dl or mkvpropedit") { options.pretend = true } # Mostly for testing code that doesn't rely on the programs actually running.
      opts.on('--no-download', "Run operations that don't require downloading.") { options.no_download = true }
      opts.on('--no-stats', "Don't calculate statistics for MKV files.") { options.stats = false }
      opts.on('--webm', 'use webm instead of mkv for merging files (videos that have separate files per stream).') { options.webm = true }
      # opts.on('-m', '--mux', 'mux non-mkv files') { options.mux = true }
      # opts.on('--convertmkv-config', 'Location for the convertmkv configuration file.') { |c| options.config = c } # Reusing the convertmkv config file since the options used are the same.
      opts.on('-k', '--keep-original', 'Keep the original file if muxing non-mkv files.') { options.keep_original = true }
      opts.on('-ks', '--keep-split', 'Keep the original split download files (if there are any)') do
        options.keep_split = true
        options.no_mux = true
      end
      opts.on('--ffmpeg-download', 'Download using ffmpeg') { options.ffmpegdl = true } # hoping this will fix certain video downloads
      opts.on('--no-playlist', "Don't create a playlist") { options.playlist = false }
      opts.on('--playlist-path [FILE]', 'Location to save the playlist') { |i| options.playlistpath = Pathname.new(i) }
      opts.on('--reset-playlist', 'Do not modify an existing playlist (if it exists)') { options.resetplaylist = true }
      opts.on('--no-blacklist', 'Do not put downloaded files in the playlist blacklist.') { options.no_blacklist = true }
      opts.on('--no-sort', 'Do not run any sorting operations.') { options.sort = false }
      opts.on('--drive-letter [LETTER]', 'Drive letter to use for the xspf playlist (not used if directory is set to default)') { |i| options.drive_letter = i }
    end
    optparse.parse!(args)
    options
  end
end
args = lambda do
  arg = ARGV.dup
  arg.cleanup!
  outarg = Options.parse(arg)
  outurl = arg.dup
  outurl.keep_if { |url| url.is_a?(String) }
  outurl.keep_if { |url| url =~ /\A#{URI.regexp(%w[http https])}\z/ }
  [outarg.freeze, outurl.freeze]
end

Args, urls = args.call

ytdl = YTDL::Fetch.new(Args.directory, urls, sort: Args.sort, pretend: Args.pretend, subdirectory: Args.subdirectory, datesubdir: Args.datesubdir)
ytdl.fetch_filenames!
ytdl.setarchive!(Args.Archive)
ytdl.fetch_videos(webmout: Args.webm, force: Args.force, keep_split: Args.keep_split, ffmpegdl: Args.ffmpegdl)

files = YTDL.findfiles(ytdl.directory, sort: Args.sort, pretend: Args.pretend)

playlistpath =
  case
  when Args.playlistpath
    Args.playlistpath
  when [ytdl.directory.to_s.include?('/data/Videos/Youtube'), Args.subdirectory].all?
    Pathname.new("/data/Videos/Youtube/Playlists/#{Args.subdirectory}/#{Args.date}.xspf")
  when [ytdl.directory.to_s.include?('/data/Videos/Youtube'), !Args.subdirectory].all?
    Pathname.new("/data/Videos/Youtube/Playlists/#{Args.date}.xspf")
  else
    Pathname.new("#{ytdl.directory}/Playlists/#{Args.date}.xspf")
  end
root = ytdl.directory.to_s.include?('/data/Videos') ? '/data/Videos' : ytdl.directory.parent.to_s

stats = YTDL::Stats.new(files, pretend: Args.pretend)
stats.genstatsfl!
stats.genstats

pl = YTDL::Playlist.new(ytdl.filenames, playlistpath, ytdl.directory, root, reset_playlist: Args.resetplaylist, pretend: Args.pretend, noblacklist: Args.no_blacklist)
pl.blackist unless Args.playlist
pl.genplfilelist! if Args.playlist
pl.genplaylist if Args.playlist
