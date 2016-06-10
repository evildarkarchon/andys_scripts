#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require 'pathname'
require 'json'

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

  options.dbpath = './videocodec.sqlite'
  options.converttest = true
  options.config = Pathname.new(Dir.home).join('.config/absconvert.json')
  options.container = '.mkv'
  options.sort = true
  options.debug = false

  options.backup = nil
  options.outputdir = Pathname.new('..').realpath

  optparse = OptionParser.new do |opts|
    opts.on('--video-codec [codec]', 'Video codec for the output file.') do |vcodec|
      options.videocodec = vcodec
    end

    opts.on('--video-bitrate [codec]', 'Video bitrate for the output file.') do |vbitrate|
      options.videobitrate = vbitrate
    end

    opts.on('--passes [pass]', '-p [pass]', 'Number of video encoding passes.') do |passes|
      raise ArgumentError unless passes.respond_to?(:to_i)
      if passes > 2
        options.passes = 2
      else
        options.passes = passes.to_i
      end
    end
  end
  optparse.parse!(args)
  options
end
