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

  optparse = OptionParser.new do |opts|
    opts.on('--video-codec [libvpx-vp9]', '-vc', 'Video codec for the output file.') do |vcodec|
      options.videocodec = vcodec
    end

    opts.on('--video-bitrate [bitrate]', '-vb', 'Video bitrate for the output file.') do |vbitrate|
      options.videobitrate = vbitrate
    end
  end
  optparse.parse!(args)
  options
end
