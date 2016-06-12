#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'json'
require 'filemagic'

require_relative 'andyrb/mood'
require_relative 'andyrb/util'
require_relative 'andyrb/abs'

class Options
  options = OpenStruct.new
  options.videocodec = 'libvpx-vp9'
  options.videobitrate = nil
  options.framerate = nil
  options.passes = 2

  options.audiocodec = 'opus'
  options.audiobitrate = nil
  options.audiofilter = 'aresample=async=1:min_comp=0.001:first_pts=0'

  options.dbpath = Pathname.new('./videocodec.sqlite')
  options.converttest = true
  options.config = Pathname.new(Dir.home).join('.config/absconvert.json')
  options.container = '.mkv'
  options.sort = true
  options.debug = false

  options.backup = nil
  options.outputdir = Pathname.new('..').realpath unless Dir.pwd == Dir.home
  options.outputdir = Pathname.new(Dir.home) if Dir.pwd == Dir.home

  optparse = OptionParser.new do |opts|
    opts.on('--video-codec [codec]', 'Video codec for the output video.') { |vcodec| options.videocodec = vcodec }

    opts.on('--video-bitrate [bitrate]', 'Video bitrate for the output video.') { |vbitrate| options.videobitrate = vbitrate }

    opts.on('--passes [pass]', '-p [pass]', 'Number of video encoding passes.') do |passes|
      raise ArgumentError unless passes.respond_to?(:to_i)
      if passes > 2
        options.passes = 2
      else
        options.passes = passes.to_i
      end
    end

    opts.on('--frame-rate [rate]', '-f [rate]', 'Manually specify the frame rate (e.g. useful for MPEG2-PS files)') { |fr| options.framerate = fr.to_f if fr.respond_to?(:to_f) }

    opts.on('--audio-bitrate [bitrate]', 'Bitrate of the output audio.') { |abitrate| options.audiobitrate = abitrate }

    opts.on('--audio-codec [codec]', 'Codec of the output audio.') { |acodec| options.audiocodec = acodec }

    opts.on('--audio-filter [filter]', 'Filter to be used for the output audio.') { |afilter| options.audiofilter = afilter }

    opts.on('--database [location]', 'Location of the videoinfo database') { |db| options.dbpath = Pathname.new(db) }

    opts.on('--convert-test', "Don't delete any videoinfo entries.") { |ct| options.converttest = ct }

    opts.on('--config [path]', '-c [path]', 'Location of the configuration json file') { |config| options.config = Pathname.new(config) }

    opts.on('--container [extension]', 'Container to be used for the output file (the dot must be included).') { |ext| options.container = ext }

    opts.on('--no-sort', "Don't sort the file list.") { options.sort = false }

    opts.on('--debug', '-d', 'Print variables and exit.') { options.debug = true }

    opts.on('--backup [dir]', '-b [dir]', 'Location of the backup directory (if any)') { |backup| options.backup = backup }

    opts.on('--output [dir]', '-o [dir]', 'Location of the output directory') { |output| options.outputdir = Pathname.new(output) }
  end
  optparse.parse!(args)
  options
end

options = Options.parse(ARGV)
options.files = []
options.files = ARGV unless ARGV.nil? || ARGV.empty?
=begin
if options.files.empty?
  Find.find(Dir.getwd) do |path|
    if File.basename(path)[0] == ?. # rubocop:disable Style/CharacterLiteral
      Find.prune # Don't look any further into this directory.
    else
      puts path if options.debug
      options.files << path
      next
    end
  end
end
=end

def filterfilelist(filelist, testmode = options.debug)
  whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']
  magic = FileMagic.new(:mime_type)
  inlist = Util::SortEntries.sort(filelist) if options.sort == true
  inlist = filelist unless options.sort == true
  puts 'Files to be examined:' if testmode
  outlist = []
  inlist.each do |entry|
    if testmode
      puts magic.flags
      puts magic.file(entry)
    end
    # puts 'Good' if whitelist.include?(magic.file(entry))
    # puts 'Bad' unless whitelist.include?(magic.file(entry))
    outlist << entry if whitelist.include?(magic.file(entry)) && !testmode
    puts(Mood.happy(entry)) if whitelist.include?(magic.file(entry)) && testmode
  end
  magic.close
  outlist
end
options.files = filterfilelist(options.files)
