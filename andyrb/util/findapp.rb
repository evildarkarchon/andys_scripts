# frozen_string_literal: true
module Util
  class FindApp
    def self.which(cmd)
      exe = nil
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          which = File.join(path, "#{cmd}#{ext}")
          exe = which if File.executable?(which) && !File.directory?(which)
        end
      end
      yield exe if block_given?
      exe
    end
  end
end
