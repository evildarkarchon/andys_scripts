#!/usr/bin/env ruby
require 'pathname'
require 'shellwords'
require 'logger'
require 'optparse'
require 'date'
require 'subprocess'
require 'tempfile'
require 'fileutils'

require_relative 'andyrb/util'
class Options
  def self.parse(args)
    options = OpenStruct.new
    options.cron = false

    optparse = OptionParser.new do |opts|
      opts.on('-c', '--cron', "Don't output pretty text and enable logging.") { options.cron = true }
    end
    optparse.parse!(args)
    options
  end
end
ARGV.flatten! if ARGV.respond_to?(:flatten!)
ARGV.compact! if ARGV.respond_to?(:compact!)
Args = Options.parse(ARGV)
Now = Time.now.strftime('%Y%m%d_%H%M')

Log = Logger.new('/var/log/ttrss_backup.log', 'monthly') if Args.cron
Log = nil unless Args.cron

PgDump = Util::FindApp.which('pg_dump')
Xz = Util::FindApp.which('xz')

Tempfile.open('ttrss_') do |f|
  tmppath = Pathname.new(f.path)
  xzpath = tmppath.sub_ext('.xz')

  Subprocess.check_call(%W(#{PgDump} -C -c --if-exists -d feeds -U postgres), stdout: Subprocess::PIPE) do |p|
    puts "Dumping database to #{tmppath}" unless Log.respond_to?(:info)
    Log.info { "Dumping database to #{tmppath}" } if Log.respond_to?(:info)
    f.write p.communicate[0]
    f.fsync
  end

  # puts f.path
  out = "/data/ttrssbackup/feeds-#{Now}.xz"
  puts "Compressing #{tmppath} to #{out}" unless Log.respond_to?(:info)
  Log.info { "Compressing #{tmppath} to #{out}" } if Log.respond_to?(:info)
  Subprocess.check_call(%W(#{Xz} -k -T 0 #{tmppath}))
  begin
    FileUtils.mv(xzpath.to_s, out)
    FileUtils.chmod(0o644, out)
  ensure
    FileUtils.rm(xzpath.to_s) if xzpath.exist?
  end
end

clean = Pathname.find('/data/ttrssbackup').to_a
clean.keep_if(&:file?)

clean.each do |f|
  diff = Util::DateDiff.getdiff(f.mtime)
  puts "Removing #{f}" if diff > 14 && !Log.respond_to?(:info)
  Log.info { "Removing #{f}" } if diff > 14 && Log.respond_to?(:info)
  f.delete if diff > 14
end
