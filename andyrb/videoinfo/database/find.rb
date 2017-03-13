require 'filemagic'
require 'find'

require_relative '../../mood'

module VideoInfo
  module Database
    def self.find(directory, verbose = false)
      magic = FileMagic.new

      dirpath = Pathname.new(directory)

      blacklist = /jpg|gif|png|flv|mp4|mkv|webm|vob|ogg|drc|avi|wmv|yuv|rm|rmvb|asf|m4v|mpg|mp2|mpeg|mpe|mpv|3gp|3g2|mxf|roq|nsv|f4v|wav|ra|mka|pdf|odt|docx|webp|swf|cb7|zip|7z|xml|log/i

      initdirectories = dirpath.find.to_a
      initdirectories.keep_if(&:file?)
      initdirectories.delete_if { |i| i.extname =~ blacklist }
      initdirectories.keep_if { |i| magic.file(i.to_s).include?('SQLite 3.x') }

      directories = initdirectories.map(&:dirname)

      if verbose
        directories.each do |i|
          puts 'Non-deduped directory list:'
          puts Mood.happy(i.to_s)
          puts
        end
      end

      directories.uniq!

      if verbose
        directories.each do |i|
          puts 'De-duped directory list:'
          puts Mood.happy(i.to_s)
        end
      end

      yield directories if block_given?
      directories
    end
  end
end
