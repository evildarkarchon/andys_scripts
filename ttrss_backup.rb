require 'pathname'
require 'shellwords'
begin
  require 'systemd/journal'
rescue LoadError
  require 'logger'
end
require 'optparse'
require 'date'

require_relative 'andyrb/util'
class Options
  def self.parse(args)
    options = OpenStruct.new
    options.cron = false

    optparse = OptionParser.new do |opts|
      opts.on('-c', '--cron', "Don't output to the terminal and instead output to the log.") { options.cron = true }
    end
    optparse.parse!(args)
    options
  end
end
ARGV.flatten! if ARGV.respond_to?(:flatten!)
ARGV.compact! if ARGV.respond_to?(:compact!)
Args = Options.parse(ARGV)
Now = Time.now.strftime('%Y%m%d_%H%M')

def class_exists?(name)
  klass = Module.const_get(name)
  klass.is_a?(Class) unless klass.is_a?(Module)
  klass.is_a?(Module) if klass.is_a?(Module)
  false unless klass.is_a?(Module) || klass.is_a?(Module)
rescue NameError
  false
end
logger = Logger.new('/var/log/ttrss_backup.log', 'monthly') if Args.cron && !class_exists?('Systemd::Journal')
sdlog = Systemd::Journal.new if Args.cron && class_exists?('Systemd::Journal')
