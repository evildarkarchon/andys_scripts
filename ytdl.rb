#!/usr/bin/env ruby
require 'optparse'
require 'subprocess'
require 'pathname'
require 'filemagic'
# require 'json'

require_relative 'andyrb/videoinfo_dm'
require_relative 'andyrb/mood'
require_relative 'andyrb/util'

class Options
  def self.parse(args)
    options = OpenStruct.new
    options.date = Time.now.strftime("%Y%m%d") # rubocop:disable Style/StringLiterals, Lint/UnneededDisable
    options.directory = Pathname.new('/data/videos/Youtube')
    options.no_date = false
    options.force = false

    optparse = OptionsParser.new do |opts|
      opts.on('-d DIRECTORY', '--directory=DIRECTORY', 'Name of the directory to download to') { |dir| options.directory = Pathname.new(dir) }
      opts.on('-n', '--no-date', "Don't create a subdirectory with the date.") { options.no_date = true }
      opts.on('-f', '--force', "Don't add the url(s) to the list of succesfully downloaded videos or read from said list.") { options.force = true }
    end
    optparse.parse!(args)
    options
  end
end
ARGV.compact! if ARGV.respond_to?(:compact!)
Args = Options.parse(ARGV)
Urls = ARGV

Args.directory = Args.directory + Args.date unless Args.no_date
YoutubeDL = Util::FindApp.which('youtube-dl')
MkvPropEdit = Util::FindApp.which('mkvpropedit')

case
when Args.force
  Util::Program.runprogram(%W(youtube-dl #{Urls}))
else
  Util::Program.runprogram(%W(youtube-dl --download-archive #{Args.directory}/downloaded.txt #{Urls}))
end

Files = Args.directory.find do |file|
  magic = FileMagic.new(:mime_type)
  whitelist = ['video/webm', 'video/x-matroska', 'audio/x-matroska']
  Find.prune unless whitelist.include?(magic.file(file.to_s))
  json = Util.recursive_symbolize_keys(GenerateVideoInfo::Data.probe(file))
  Find.prune if json.dig(:streams[0], :tags, :BPS)
end

Files.each do |file|
  puts Mood.happy("Adding statistic tags to #{file}.")
  Util::Program.runprogram(%W(#{MkvPropEdit} --add-track-statistics-tags #{file}))
end
