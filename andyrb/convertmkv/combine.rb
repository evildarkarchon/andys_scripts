# frozen_string_literal: true

require 'tempfile'
require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../core/cleanup'

# Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
# Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Array::Cleanup) : Array.include(AndyCore::Array::Cleanup)

module ConvertMkv
  class Combine
    def initialize(filelist, outname, verbose: false, paths: nil)
      raise TypeError, 'filelist must be an array or convertable to one' unless filelist.respond_to?(:to_a)
      @filelist = filelist
      @outname = outname.is_a?(Pathname) ? outname : Pathname.new(outname)
      @verbose = verbose
      @paths = paths ? paths : { mkvmerge: Util::FindApp.which('mkvmerge'), ffmpeg: Util::FindApp.which('ffmpeg'), mkvpropedit: Util::FindApp.which('mkvpropedit') }
      @audio = audio
    end

    def ffmpeg
      Tempfile.open('concat_') do |f|
        @filelist.each do |i|
          f.write("#{i}\n")
          f.fsync
        end
        begin
          Util::Program.runprogram(%W[#{@paths[:ffmpeg]} -f concat -safe 0 -i #{f.path} -c copy #{@outname}])
        rescue Interrupt => e
          raise e
        else
          Util::Program.runprogram(%W[#{@paths[:mkvpropedit]} --add-track-statistics-tags #{@outname}])
        end
      end
    end

    def mkvmerge(options: nil)
      filelist = @filelist.dup.join(' + ')
      filelist = filelist.split.freeze

      command = %W[#{@paths[:mkvmerge]} -o #{@outname}]
      command += options if options
      command += filelist
      command.cleanup!(unique: false).freeze

      Util::Program.runprogram(command)
    end
  end
end
