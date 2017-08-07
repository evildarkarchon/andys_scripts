# frozen_string_literal: true

require 'pathname'
require 'filemagic'

begin
  rv = Gem::Version.new(RUBY_VERSION.to_s.freeze)
  rvm = Gem::Version.new('2.3.0')
  require 'ruby_dig' if rv < rvm
rescue LoadError => e
  raise e if rv < rvm
end

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../videoinfo/probe'
require_relative '../mood'

module YTDL
  class Stats
    def initialize(filelist, pretend: false)
      @pretend = pretend
      @filelist = filelist.dup
    end

    def genstatsfl!
      whitelist = %w[video/webm video/x-matroska audio/x-matroska].freeze
      @filelist.keep_if do |file|
        file.freeze
        magic = FileMagic.new(:mime_type)
        whitelist.include?(magic.file(file.to_s))
      end
      puts Mood.neutral('Step 2 (stats):') if @pretend

      puts @filelist.inspect if @pretend
      @filelist.delete_if do |file|
        file.freeze
        jsondata = VideoInfo.probe(file)
        jsondata.freeze unless frozen?
        jsondata.dig(:streams, 0, :tags, :BPS)
      end
      @filelist.freeze
      puts Mood.neutral('Step 3 (stats):') if @pretend

      puts @filelist.inspect if @pretend
      puts Mood.neutral('No matroska files to calculate statistics for.') if [@filelist.nil?, @filelist.empty?].any?
    end

    def genstats
      Util.findapp('mkvpropedit') do |mpe|
        mpe.freeze
        raise "Couldn't find mkvpropedit" unless mpe
        raise 'mkvpropedit is not executable' unless mpe && File.executable?(mpe)
        if [@filelist.respond_to?(:each), @filelist.respond_to?(:empty?) && !@filelist.empty?].all?
          @filelist.each do |file|
            puts(Mood.happy { "Adding statistic tags to #{file}" })
            cmd = %W[#{mpe} --add-track-statistics-tags #{file}].freeze
            begin
              Util.runprogram(cmd) unless @pretend

              puts cmd.inspect if @pretend
            rescue Subprocess::NonZeroExit => e
              puts e.message
              next
            end
          end
        end
      end
    end

    def inspect
      "YTDL::Stats<@filelist = #{@filelist}, @pretend = #{@pretend}>"
    end
  end
end
