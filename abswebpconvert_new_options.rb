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

# class Options
#   def self.parse(args)
#     options = OpenStruct.new
#     # options.quality = '80'
#     options.verbose = false
#     # options.lossy = nil
#     # options.lossless = nil
#     options.preset = 'default'
#     options.outputdir = Pathname.getwd
#     options.backup = nil
#     options.nobackup = false
#     options.archive = nil
#     # options.backuparchive = Pathname.getwd.join("Original Files/#{Pathname.getwd.basename}.7z").to_s
#     cwd = Pathname.getwd
#     # options.backuparchive = Dir.getwd + "Original Files/#{File.basename(Dir.getwd)}.7z" unless Dir.getwd.include?('Just Downloaded')
#     # options.backuparchive = (Pathname.getwd.parent + "Original Files/#{File.basename(Dir.getwd)}.7z").to_s if Dir.getwd.include?('Just Downloaded')
#     options.backuparchive = (cwd + 'Original Files' + "#{cwd.basename}.7z").to_s unless cwd.to_s.include?('Just Downloaded')
#     options.backuparchive = (cwd.parent + 'Original Files' + "#{cwd.parent.basename}.7z").to_s if cwd.to_s.include?('Just Downloaded')
#     options.removeoriginal = true
#     options.force = false
#     options.sort = true
#     options.mode = 'lossy'
#     options.explicit = false

#     optparse = OptionParser.new do |opts|
#       opts.on('--quality [n]', '-q [n]', 'Quality factor (0-100), 80 is default.') { |q| options.quality = q.to_s }
#       opts.on('--verbose', '-v', 'Make convert more chatty.') { options.verbose = true }
#       opts.on('--lossy', 'Produce lossy images.') do
#         options.mode = 'lossy' unless options.explicit
#         options.explicit = true unless options.explicit
#       end
#       opts.on('--lossless', 'Produce lossless images.') do
#         options.mode = 'lossless' unless options.explicit
#         options.explicit = true unless options.explicit
#       end
#       opts.on('--output-dir [DIRECTORY]', '-o [DIRECTORY]', 'Directory to output resulting images (default is current directory)') { |dir| options.outputdir = Pathname.new(dir.to_s) }
#       opts.on('--backup-dir [DIRECTORY]', '-b [DIRECTORY]', 'Directory to move source images to.') { |dir| options.backup = Pathname.new(dir.to_s) }
#       opts.on('--no-backup', 'Disable Backup.') { options.nobackup = true }
#       opts.on('--archive [FILENAME]', 'Put the resulting images into a 7z archive.') { |archive| options.archive = archive }
#       opts.on('--backup-archive [FILENAME]', 'Put the original images into a 7z archive.') do |archive|
#         options.backuparchive = archive == 'none' ? nil : archive
#       end
#       opts.on('--no-remove-original', 'Disables removing the original file when making archives') { options.removeoriginal = false }
#       opts.on('--force', '-f', 'Remove any files with the same name as the resulting file.') { options.force = true }
#       opts.on('--no-sort', "Don't sort the argument list.") { options.sort = false }
#     end
#     optparse.parse!(args)
#     options
#   end
# end

Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)

# Args = Options.parse(ARGV)
# ARGV.cleanup!(unique: false)

# Files = Args.sort ? Util.sort(ARGV.dup) : ARGV.dup
# args = lambda do
#   arg = ARGV.dup
#   arg.cleanup!
#   outarg = options.parse(arg)
#   outfiles = Args.sort ? arg.dup.natsort : arg.dup
#   [outarg.freeze, outfiles.freeze]
# end

args = Options.new(ARGV.dup.cleanup) do |defaults|
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
  defaults[:explicit] = false
  defaults[:debug] = false
end
def args.files
  out = super.source.dup
  out.keep_if { |i| File.file?(i) }
  out = super.args[:sort] ? out.natsort : out
  out.freeze
end
args.construct! do |h, i|
  h.on('--quality [n]', '-q [n]', Integer, 'Quality factor (0-100), 80 is default.') { |o| i[:quality] = o }
  h.on('--verbose', '-v', 'Make the script more chatty') { i[:verbose] = true }
  h.on('--lossy', 'Encode images in lossy mode.') do
    i[:mode] = 'lossy' unless i[:explicit]
    i[:explicit] = true unless i[:explicit]
  end
  h.on('--lossless', 'Encode images in lossless mode.') do
    i[:mode] = lossless unless i[:explicit]
    i[:explicit] = true unless i[:explicit]
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
Args, Files = args.call
NoBackup = true if [[Args.removeoriginal, Args.backuparchive, !Args.nobackup].all?, Args.nobackup].any?
Args.freeze

Args.outputdir.mkpath unless [Args.outputdir.exist?, Args.outputdir.directory?, !Args.outputdir.file?].all?
raise "#{Args.outputdir} is not a directory." unless Args.outputdir.directory?

case
when Args.backup && Args.backup.respond_to?(:directory?)
  Args.backup.mkpath unless Args.backup.directory? || NoBackup
  raise "#{Args.backup} is not a directory." unless [Args.backup.directory?, NoBackup].any?
  Args.backup = Args.backup.realpath unless NoBackup
end

class Command
  attr_reader :list, :outpath, :filepath
  def initialize(filename)
    @filepath = Pathname.new(filename).realpath.freeze
    ext = @filepath.extname.downcase.freeze
    magic = FileMagic.new(:mime_type)
    @outpath = Pathname.new(Args.outputdir).realpath + Pathname.new(filepath.basename.to_s).sub_ext('.webp').to_s.freeze

    lossless_mime = %w[image/png image/gif image/tiff image/x-pcx application/tga application/x-tga application/x-targs image/tga image/x-tga image/targa image/x-targa image/vnd.adobe.photoshop].cleanup!(unique: false).freeze

    raw = %w[.3fr .ari .arw .srf .sr2 .bay .crw .cr2 .cap .iiq .eip .dcs .dcr .drf .k25 .kdc .dng .erf .fff .mef .mdc .mos .mrw]
    raw += %w[.nef .nrw .orf .pef .ptx .pxn .r3d .raf .raw .rw2 .rwl .rwz .srw .x3f]
    raw.cleanup!(unique: false).freeze

    # lossless = ['-define', 'webp:lossless=true']
    lossless = %w[-define webp:lossless=true].freeze
    # lossymode = Args.lossy
    # losslessmode = Args.lossless
    outmode = Args.mode
    # if (lossless_mime.include?(magic.file(@filepath.to_s)) || raw.include?(ext)) && !outmode == 'lossy'
    if [[lossless_mime.include?(magic.file(@filepath.to_s)), raw.include?(ext)].any?, !Args.explicit].all?
      outmode = 'lossless'
    end

    Util::FindApp.which('convert') do |c|
      raise 'convert not found or is not executable.' unless c && File.executable?(c)
      @list = %W[#{c} #{filepath}]
      @list << %W[-quality #{Args.quality}]
      @list << lossless if outmode == 'lossless'
      @list << %w[-define webp:thread-level=1]
      @list << '-verbose' if Args.verbose
      @list << @outpath.to_s
      @list.cleanup!(unique: false)
      @list.freeze
    end
  end
end

def backuparchive
  backuparchivepath = Pathname.new(Args.backuparchive).freeze
  case
  when [backarchivepath.parent.exist?, !backuparchive.parent.directory?].all?
    raise "#{backuparchivepath.parent} is not a directory."
  when !backuparchivepath.parent.directory?
    puts Mood.happy("Creating directory #{backuparchivepath.parent}")
    backuparchivepath.parent.mkpath
  end
  puts Mood.happy("Backing up original files to #{backuparchivepath}")

  paths = Files.dup
  paths.map! { |i| Pathname.new(i) }
  paths.freeze

  begin
    Util::FindApp.which('7za') do |z|
      z.freeze
      raise '7za not found or is not executable.' if [[Args.backuparchive, !z].all?, [Args.backuparchive, z, !File.executable?(z)].all?].any?
      Util::Program.runprogram(%W[#{z} a #{Args.backuparchive} #{paths.join(' ')}])
    end
  rescue Subprocess::NonZeroExit => e
    puts e.message
    raise e
  else
    if Args.removeoriginal
      paths.each do |file|
        file.freeze
        puts Mood.happy("Removing #{file}")
        file.delete
      end
    end
  end
end

def archive
  archivepath = Pathname.new(Args.archive)
  puts Mood.happy("Creating directory #{archivepath.parent}") unless archivepath.parent.directory?
  archivepath.parent.mkpath unless archivepath.parent.directory?
  archivepath = archivepath.realpath
  archivepath.freeze

  paths = Files.dup
  paths.map! { |file| Pathname.new(file).realpath.sub_ext('.webp').to_s }
  paths.freeze

  puts Mood.happy("Adding files to #{archivepath}")
  begin
    # Util::Program.runprogram([SevenZ, 'a', Args.archive, paths.join(' ')])
    Util::FindApp.which('7za') { |z| Util::Program.runprogram(%W[#{z} a #{Args.archive} paths.join(' ')]) }
  rescue Subprocess::NonZeroExit, Interrupt => e
    puts e.message.freeze
    raise e
  else
    if Args.removeoriginal
      paths.each do |file|
        file.freeze
        puts Mood.happy("Removing #{file}")
        file.delete
      end
    end
  end
end

Files.each do |file|
  file.freeze
  cmdline = Command.new(file)
  outname = cmdline.outpath.to_s.freeze
  if [cmdline.outpath.exist?, !Args.force].all?
    puts(Mood.neutral { "#{cmdline.outpath} already exists, skipping." })
    next
  elsif [cmdline.outpath.exist?, Args.force].all?
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

  next if NoBackup
  next unless Args.backup.respond_to?(:exist?)
  puts Mood.happy("Moving #{cmdline.filepath.basename} to #{Args.backup}")
  FileUtils.mv(file, Args.backup.to_s)
end
backuparchive if Args.backuparchive
archive if Args.archive
