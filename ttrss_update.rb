#!/usr/bin/env ruby
require 'pathname'
require 'fileutils'
require 'optparse'

require_relative 'andyrb/util'
require_relative 'andyrb/git'
require_relative 'andyrb/mood'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.aggressive = false
    options.replace = false

    optparse = OptionParser.new do |opts|
      opts.on('-a', '--aggressive', 'Activate git gc in aggressive mode if run.') { options.aggressive = true }
      opts.on('-r', '--replace', 'Rename any existing directory if a repository is not found.') { options.replace = true }
    end
    optparse.parse!(args)
    options
  end
end

ARGV.compact! if ARGV.respond_to?(:compact!)
ARGV.flatten! if ARGV.respond_to?(:flatten!)
ARGV.uniq! if ARGV.respond_to?(:uniq!)
Args = Options.parse(ARGV)
TTrss = Git.new('/data/web/feeds', use_sudo: True, sudo_user: 'nginx')
at_exit do
  TTrss.clean_lock
end

def ttrssgcfile
  cachepath = Pathname.new('/var/cache/ttrssgc')
  use_sudo = false
  use_sudo = true unless cachepath.parent.writable?
  case
  when use_sudo
    Util::Program.runprogram(%W(touch #{cachepath}), use_sudo: true)
  else
    FileUtils.touch(cachepath.to_s)
  end
end

ttrssgcfile unless File.exist?('/var/cache/ttrssgc')

def ttrssgc(thendate)
  diff = Util::Datediff.getdiff(thendate)
  TTrss.gc(Args.aggressive) if diff >= 30
end

repopath = Pathname.new('/data/web/feeds/.git')
wdpath = repopath.parent
giturl = 'https://tt-rss.org/gitlab/fox/tt-rss.git'
case
when repopath.directory?
  TTrss.clean_lock
  TTrss.pull
when wdpath.exist? && !repopath.exist?
  case
  when Args.replace
    puts Mood.neutral("No git repository located in the target directory, renaming it to #{wdpath}.old")
    Util::Program.runprogram(%W(mv #{wdpath} #{wdpath}.old), use_sudo: true, sudo_user: 'nginx')
    TTrss.clone(giturl)
  else
    puts Mood.sad('No git repository located in the target directory.')
    raise
  end
when wdpath.file?
  puts Mood.neutral('Target location is a file, renaming and cloning repository.')
  Util::Program.runprogram(%W(mv #{wdpath} #{wdpath}.bad), use_sudo: true, sudo_user: 'nginx')
  TTrss.clone(giturl)
else
  puts Mood.neutral('Target location does not exist, cloning repository')
  TTrss.clone(giturl)
end

ttrssgc(File.stat('/var/cache/ttrssgc').mtime)
