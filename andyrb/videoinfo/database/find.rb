# frozen_string_literal: true

require 'filemagic'
require 'find'

require_relative '../../mood'

module VideoInfo
  module Database
    def self.find(directory, verbose = false)
      magic = FileMagic.new

      dirpath = Pathname.new(directory).freeze

      blacklist = /jpg|gif|png|flv|mp4|mkv|webm|vob|ogg|drc|avi|wmv|yuv|rm|rmvb|asf|m4v|mpg|mp2|mpeg|mpe|mpv|3gp|3g2|mxf|roq|nsv|f4v|wav|ra|mka|pdf|odt|docx|webp|swf|cb7|zip|7z|xml|log/i

      initdirectories = dirpath.find.to_a
      initdirectories.keep_if(&:file?)
      initdirectories.delete_if { |i| i.extname =~ blacklist }
      initdirectories.keep_if { |i| magic.file(i.to_s).include?('SQLite 3.x') }
      initdirectories.freeze
      # puts 'find 1:'
      # print "#{initdirectories}\n"
      # puts

      directories = initdirectories.map(&:dirname)
      # puts 'find 2:'
      # print "#{directories}\n"
      # puts

      if verbose
        puts 'Non-deduped directory list:'
        # puts 'find 3:'
        p directories
      end

      directories.uniq!
      directories.freeze
      # puts 'find 4:'
      # print "#{directories}\n"
      # puts
      if verbose
        # puts 'find 5:'
        puts 'De-duped directory list:'
        p directories
        puts
      end

      yield directories if block_given?
      directories
    end
  end
end
