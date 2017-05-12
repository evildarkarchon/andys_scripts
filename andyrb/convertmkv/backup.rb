# frozen_string_literal: true

require 'pathname'
require 'fileutils'

require_relative '../mood'

module ConvertMkv
  def self.backup(sourcefile, dest)
    sourcefile = sourcefile.is_a?(Pathname) ? sourcefile : Pathname.new(sourcefile)
    dest = dest.is_a?(Pathname) ? dest : Pathname.new(dest)

    puts Mood.happy("Moving #{sourcefile} to #{dest}")
    begin
      sourcefile.rename(dest.joinpath(sourcefile.basename).to_s)
    rescue SystemCallError
      dest.parent.mkpath unless dest.exist?
      FileUtils.mv(sourcefile.to_s, dest.joinpath(sourcefile.basename).to_s) if dest.writable?
    end
  end
end
