# frozen_string_literal: true

require 'pathname'
require 'subprocess'

require_relative '../util/findapp'
require_relative '../util/program'
require_relative '../mood'

module ABSWebPConvert
  def self.backuparchive(files, outfile, removeoriginal: true)
    backuparchivepath = Pathname.new(outfile).freeze
    case
    when [backarchivepath.parent.exist?, !backuparchive.parent.directory?].all?
      raise "#{backuparchivepath.parent} is not a directory."
    when !backuparchivepath.parent.directory?
      puts Mood.happy("Creating directory #{backuparchivepath.parent}")
      backuparchivepath.parent.mkpath
    end
    puts Mood.happy("Backing up original files to #{backuparchivepath}")

    paths = files.map { |i| Pathname.new(i) }
    paths.freeze

    begin
      Util::FindApp.which('7za') do |z|
        z.freeze
        Util::Program.runprogram(%W[#{z} a #{backuparchivepath} #{paths.join(' ')}])
      end
    rescue Subprocess::NonZeroExit => e
      puts e.message
      raise e
    else
      if removeoriginal
        paths.each do |file|
          file.freeze
          puts Mood.happy("Removing #{file}")
          file.delete
        end
      end
    end
  end

  def self.archive(files, outfile, removeoriginal: true)
    archivepath = Pathname.new(outfile)
    puts Mood.happy("Creating directory #{archivepath.parent}") unless archivepath.parent.directory?
    archivepath.parent.mkpath unless archivepath.parent.directory?
    archivepath = archivepath.realpath
    archivepath.freeze

    paths = files.map { |file| Pathname.new(file).realpath.sub_ext('.webp').to_s }
    paths.freeze

    puts Mood.happy("Adding files to #{archivepath}")
    begin
      Util::FindApp.which('7za') { |z| Util::Program.runprogram(%W[#{z} a #{archivepath} paths.join(' ')]) }
    rescue Subprocess::NonZeroExit, Interrupt => e
      puts e.message
      raise e
    else
      if removeoriginal
        paths.each do |file|
          file.freeze
          puts Mood.happy("Removing #{file}")
          file.delete
        end
      end
    end
  end
end
