#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'

require_relative 'andyrb/convertmkv'
require_relative 'andyrb/options'
require_relative 'andyrb/core/sort'
require_relative 'andyrb/core/cleanup'
require_relative 'andyrb/core/monkeypatch'

# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)
AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)
AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

opts = Options.new(ARGV.dup.cleanup!) do |defaults|
  defaults[:audio] = false
  defaults[:sort] = true
  defaults[:ffmpeg] = false
  defaults[:outputdir] = Pathname.getwd
  defaults[:backup] = nil
  defaults[:combine] = false
  defaults[:debug] = false
  defaults[:verbose] = false
  defaults[:config] = "#{Dir.home}/.config/convertmkv.json"
  defaults[:ffmpegpath] = nil
  defaults[:mkvmergepath] = nil
  defaults[:mkvpropeditpath] = nil
end
opts.construct! do |h, i|
  h.on('-f', '--ffmpeg', 'Use ffmpeg instead of mkvmerge. Note: ffmpeg hates mpeg2-ps files.') { i[:ffmpeg] = true }
  h.on('--ffmpeg-path path', 'Path to the ffmpeg executable (if not in normal search path)') { |f| i[:ffmpegpath] = f }
  h.on('--mkvmerge-path path', 'Path to the mkvmerge executable (if not in normal search path)') { |m| i[:mkvmergepath] = m }
  h.on('--mkvpropedit-path path', 'Path to the mkvpropedit executable (if not in normal search path)') { |m| i[:mkvpropeditpath] = m }
  h.on('-c', '--combine', 'Run in concatenation mode.') { i[:combine] = true }
  h.on('--no-sort', "Don't sort the list of files to be muxed.") { i[:sort] = false }
  h.on('-o directory', '--output directory', 'Directory where the muxed files will be located. (defaults to current directory)') { |o| i[:outputdir] = o }
  h.on('-b directory', '--backup directory', 'Directory where the source files will be moved.') { |o| i[:backup] = o }
  h.on('-d', '--debug', "Print what would be done, but don't actually do it") { i[:debug] = true }
  h.on('--config file', 'Location of the configuration file') { |o| i[:config] = o }
  h.on('-a', '--audio', 'Input files are audio files.') { i[:audio] = true }
end
def opts.files
  out = @source.dup
  out.keep_if { |f| File.file?(f) }
  out.natsort! if @args[:sort]
  out.freeze
end

_files = opts.files
paths = {}
paths[:mkvmerge] = opts.args[:mkvmergepath] if opts.args[:mkvmergepath]
paths[:ffmpeg] = opts.args[:ffmpegpath] if opts.args[:ffmpegpath]
paths[:mkvpropedit] = opts.args[:mkvpropeditpath] if opts.args[:mkvpropeditpath]
paths = { ffmpeg: Util::FindApp.which('ffmpeg'), mkvmerge: Util::FindApp.which('mkvmerge'), mkvpropedit: Util::FindApp.which('mkvpropedit') } if paths.empty?
