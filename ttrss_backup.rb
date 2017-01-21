require 'pathname'
require 'shellwords'
require 'logger'
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

logger = Logger.new('/var/log/ttrss_backup.log', 'monthly')
