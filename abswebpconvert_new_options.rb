#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ostruct'
require 'optparse'
require 'shellwords'
require 'subprocess'
require 'pathname'
require 'fileutils'
require 'filemagic'

require_relative 'andyrb/mood'
require_relative 'andyrb/core/cleanup'
require_relative 'andyrb/util/findapp'
require_relative 'andyrb/util/program'
require_relative 'andyrb/core/sort'

# Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
# Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)

# raise ArgumentError, "--lossy and --lossless can't be specified at the same time" if ARGV.include?('--lossy') && ARGV.include?('--lossless')

Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)

opts = Options.new(ARGV.dup.cleanup) do |defaults|
  defaults[:quality] = 80
  defaults[:verbose] = false
  defaults[:preset] = 'default'
  defaults[:outputdir] = Pathname.getwd
  defaults[:backupdir] = nil
  defaults[:backup] = true
  defaults[:archive] = nil
  cwd = Pathname.getwd
  defaults[:backuparchive] = cwd.to_s.include?('Just Downloaded') ? cwd.join("Original Files/#{cwd.basename}.7z").to_s : cwd.parent.join("Original Files/#{cwd.parent.basename}.7z").to_s
  defaults[:removeoriginal] = true
  defaults[:force] = false
  defaults[:sort] = true
  defaults[:mode] = 'lossy'
  defaults[:debug] = false
  defaults[:explicit] = false
  defaults[:conflict] = {}
end
def opts.files
  out = @source.dup
  out.keep_if { |i| File.file?(i) }
  out = @args[:sort] ? out.natsort : out
  out.freeze
end
opts.construct! do |h, i|
  h.on('--quality [n]', '-q [n]', Integer, 'Quality factor (0-100), 80 is default.') { |o| i[:quality] = o }
  h.on('--verbose', '-v', 'Make the script more chatty') { i[:verbose] = true }
  h.on('--lossy', 'Encode images in lossy mode.') do
    i[:mode] = 'lossy'
    i[:explicit] = true
    i[:conflict][:lossy] = true
  end
  h.on('--lossless', 'Encode images in lossless mode.') do
    i[:mode] = 'lossless'
    i[:explicit] = true
    i[:conflict][:lossless] = true
  end
  h.on('--output [Directory]', '-o [Directory]', String, 'Directory to output the images to.') { |o| i[:outputdir] = Pathname.new(o) }
  h.on('--backup [Directory]', '-b', String, 'Directory to save the original images to.') { |o| i[:backupdir] = Pathname.new(o) }
  h.on('--backup-archive [File]', String, 'Name of the archive to back up source images to.') { |o| i[:backuparchive] = o }
  h.on('--archive [File]', '-a [File]', String, 'Name of the archive to put the destination images into.') { |o| i[:archive] = o }
  h.on('--no-remove-original', 'Disables removing of the source file.') { i[:removeoriginal] = false }
  h.on('--force', '-f', 'Removes any files with the same name as the destination.') { i[:force] = true }
  h.on('--no-sort', 'Do not sort the file list.') { i[:sort] = false }
  h.on('--debug', 'Print variables and exit') do
    i[:debug] = true
    i[:verbose] = true
  end
end
conflict = [opts.args[:conflict].key?(:lossy) && opts.args[:conflict][:lossy], opts.args[:conflict].key?(:lossless) && opts.args[:conflict][:lossless]].any?
puts Mood.neutral('--lossy and --lossless both specified, reverting to automatic assignment.') if conflict
opts.args[:mode] = 'lossy' if conflict
opts.args[:explicit] = false if conflict
files = opts.files

opts.args[:outputdir].mkpath unless [opts.args[:outputdir].exist?, opts.args[:outputdir].directory?, !opts.args[:outputdir].file?].all?
raise "#{opts.args[:outputdir]} is not a directory." unless opts.args[:outputdir].directory?

case
when opts.args[:backupdir] && opts.args[:backupdir].respond_to?(:directory?)
  opts.args[:backupdir].mkpath unless opts.args[:backupdir].directory? || NoBackup
  raise "#{opts.args[:backupdir]} is not a directory." unless [opts.args[:backupdir].directory?, !opts.args[:backup]].any?
  opts.args[:backupdir] = opts.args[:backupdir].realpath if opts.args[:backup]
end

files.each do |file|
  file.freeze
  cmdline = ABSWebPConvert::Command.new(file, opts.args[:outputdir], opts.args[:mode], opts.args[:quality], explicit: opts.args[:explicit], verbose: opts.args[:verbose])
  outname = cmdline.outpath.to_s.freeze
  if [cmdline.outpath.exist?, !opts.args[:force]].all?
    puts(Mood.neutral { "#{cmdline.outpath} already exists, skipping." })
    next
  elsif [cmdline.outpath.exist?, opts.args[:force]].all?
    puts(Mood.neutral { "Force mode active, deleting #{cmdline.outpath}" })
    FileUtils.rm(outname)
  end

  puts Mood.happy("Converting #{cmdline.filepath} to #{cmdline.outpath.basename}")
  begin
    Util::Program.runprogram(cmdline.list)
  rescue Subprocess::NonZeroExit => e
    puts Mood.sad("#{file} was not able to be converted, skipping.")
    FileUtils.rm(outname) if cmdline.outpath.exist?
    puts e.message
    next
  rescue Interrupt => e
    FileUtils.rm(outname) if cmdline.outpath.exist?
    raise e
  end

  next unless opts.args[:backup]
  next unless opts.args[:backupdir].respond_to?(:exist?)
  puts Mood.happy("Moving #{cmdline.filepath.basename} to #{opts.args[:backupdir]}")
  FileUtils.mv(file, opts.args[:backupdir].to_s)
end
ABSWebPConvert.backuparchive(files, opts.args[:backuparchive], removeoriginal: opts.args[:removeoriginal]) if opts.args[:backuparchive]
ABSWebPConvert.archive(files, opts.args[:archive], removeoriginal: opts.args[:removeoriginal]) if opts.args[:archive]
