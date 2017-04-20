# frozen_string_literal: true

require 'tempfile'
require 'pathname'
require 'data_mapper'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../core/cleanup'
require_relative '../videoinfo/database'
require_relative '../videoinfo/genhash'

# Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
# Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Array::Cleanup) : Array.include(AndyCore::Array::Cleanup)

module ConvertMkv
  class ConCat
    def initialize(filelist, outname, database: nil, verbose: false)
      raise TypeError, 'filelist must be an array or convertable to one' unless filelist.respond_to?(:to_a)
      @filelist = filelist
      @outname = outname
      @verbose = verbose
      @database = database ? Pathname.new(database) : nil
      @gvi = nil
      @vi = nil

      if @database # rubocop:disable Style/GuardClause
        DataMapper::Model.raise_on_save_failure = true
        DataMapper.setup(:default, "sqlite:#{@database.realpath}")
        DataMapper::Logger.new($stdout, :debug)
        @gvi = VideoInfo::Database::Data.new(@database, @verbose)
        @vi = VideoInfo::Database::Videoinfo.new
      end
    end

    def ffmpeg(exepath = Util::FindApp.which('ffmpeg'))
      Tempfile.open('concat_') do |f|
        @filelist.each do |i|
          f.write("#{i}\n")
          f.fsync
        end
        Util::Program.runprogram(%W[#{exepath} -f concat -safe 0 -i #{f.path} -c copy #{@outname}])
      end
    end

    def mkvmerge(exepath = Util::FindApp.which('mkvmerge'), options: nil)
      basecommand = %W[#{exepath} -o #{Args.output}].freeze

      filelist = @filelist.dup.join(' + ')
      filelist = filelist.split.freeze

      # command = basecommand + options + filelist
      command = basecommand.dup
      command += options if options
      command += filelist
      command.cleanup!(unique: false)
      command.freeze

      Util::Program.runprogram(command)
    end
  end
end
