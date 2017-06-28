# frozen_string_literal: true

module Util
  def self.findapp(cmd, mand = false)
    exe = nil
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        which = File.join(path, "#{cmd}#{ext}")
        exe = which if File.executable?(which) && !File.directory?(which)
      end
    end
    raise "Can't find application" if [exe.nil? || exe.empty?, mand].all?
    yield exe if block_given?
    exe
  end
  class FindApp
    def self.which(cmd, mand = false)
      puts 'Util::FindApp.which is obsolete, use Util.findapp instead. Util.findapp will be called for compatibility.'
      block_given? ? Util.findapp(cmd, mand, &Proc.new) : Util.findapp(cmd)
    end
  end
end
