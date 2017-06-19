# frozen_string_literal: true

require 'pathname'

module ABSConvert
  def self.backup(source, dest)
    backuppath = Pathname.new(backupdir).freeze
    sourcepath = Pathname.new(source).freeze
    dest = backuppath + sourcepath.basename if sourcepath.exist?

    backuppath.mkpath unless backuppath.exist?
    raise 'Backup directory is a file.' if backuppath.file?
    puts(Mood.happy { "Moving #{sourcefile} to #{backupdir}" })
    sourcepath.rename(dest) if dest
  end
end
