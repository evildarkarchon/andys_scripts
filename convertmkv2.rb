#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'

require_relative 'andyrb/convertmkv'
require_relative 'andyrb/options'
require_relative 'andyrb/core/sort'
require_relative 'andyrb/core/cleanup'

Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)

opts = Options.new(ARGV.dup.cleanup!) do |defaults|
  defaults[:db] = nil
  defaults[:gvi] = false
  defaults[:sort] = true
  defaults[:ffmpeg] = false
  defaults[:outputdir] = Pathname.getwd
  defaults[:backup] = nil
  defaults[:combine] = false
  defaults[:debug] = false
  defaults[:verbose] = false
  defaults[:config] = "#{Dir.home}/.config/convertmkv.json"
end
def opts.files
  out = @source.dup
  out.keep_if { |f| File.file?(f) }
  out.natsort! if Args.sort
  out.freeze
end
opts.construct! do |h, i|
  h.on('--database file', 'Database to read metadata from (if any).') { |o| i[:db] = o }
  h.on('-f', '--ffmpeg', 'Use ffmpeg instead of mkvmerge. Note: ffmpeg hates mpeg2-ps files.') { i[:ffmpeg] = true }
  h.on('-c', '--combine', 'Run in concatenation mode.') { i[:combine] = true }
  h.on('--no-sort', "Don't sort the list of files to be muxed.") { i[:sort] = false }
  h.on('--gvi', 'Generate video info for the muxed files.') { i[:gvi] = true }
  h.on('-o directory', '--output directory', 'Directory where the muxed files will be located. (defaults to current directory)') { |o| i[:outputdir] = o }
  h.on('-b directory', '--backup directory', 'Directory where the source files will be moved.') { |o| i[:backup] = o }
  h.on('--debug', '-d', "Print what would be done, but don't actually do it") { i[:debug] = true }
  h.on('--config file', 'Location of the configuration file') { |o| i[:config] = o }
  h.on('--audio', '-a', 'Input files are audio files.') { i[:audio] = true }
end
_files = opts.files
