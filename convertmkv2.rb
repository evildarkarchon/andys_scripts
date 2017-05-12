#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'json'

require_relative 'andyrb/convertmkv'
require_relative 'andyrb/options'
require_relative 'andyrb/core/sort'
require_relative 'andyrb/core/cleanup'
require_relative 'andyrb/core/monkeypatch'
require_relative 'andyrb/util/recursive_symbolize_keys'

# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)
AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)
AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

opts = Options.new(ARGV.dup.cleanup) do |defaults|
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
  h.on('-o directory', '--output directory', 'Directory where the muxed files will be located or filename of combined file in combine mode.') { |o| i[:outputdir] = o }
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

files = opts.files
paths = {}
paths[:mkvmerge] = opts[:mkvmergepath] if opts[:mkvmergepath]
paths[:ffmpeg] = opts[:ffmpegpath] if opts[:ffmpegpath]
paths[:mkvpropedit] = opts[:mkvpropeditpath] if opts[:mkvpropeditpath]
paths = { ffmpeg: Util::FindApp.which('ffmpeg'), mkvmerge: Util::FindApp.which('mkvmerge'), mkvpropedit: Util::FindApp.which('mkvpropedit') } if paths.empty?
config = Util.recursive_symbolize_keys(JSON.parse(File.read(opts[:config])))

mux = ConvertMkv::Mux.new(files, opts[:outputdir], paths: paths, audio: opts[:audio]) unless opts[:combine]
combine = ConvertMkv::Combine.new(files, opts[:outputdir], paths: paths) if opts[:combine]

mux.mkvmerge(config[:mkvmerge]) unless opts[:combine] || opts[:ffmpeg]
mux.ffmpeg if opts[:ffmpeg] && !opts[:combine]
combine.mkvmerge if opts[:combine] && !opts[:ffmpeg]
combine.ffmpeg if opts[:combine] && opts[:ffmpeg]
files.each { |i| ConvertMkv.backup(i, opts[:backup]) } if files.respond_to?(:each)
