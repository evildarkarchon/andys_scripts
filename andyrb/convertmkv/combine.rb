# frozen_string_literal: true

require 'tempfile'
require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../core/cleanup'
require_relative '../core/monkeypatch'

AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)

module ConvertMkv
  class Combine
    def initialize(filelist, outname, verbose: false, paths: nil)
      raise TypeError, 'filelist must be an array or convertable to one' unless filelist.respond_to?(:to_a)
      @filelist = filelist
      @outname = outname.is_a?(Pathname) ? outname : Pathname.new(outname)
      @verbose = verbose
      @paths = paths ? paths : { mkvmerge: Util.findapp('mkvmerge'), ffmpeg: Util.findapp('ffmpeg'), mkvpropedit: Util.findapp('mkvpropedit') }
      @audio = audio
    end

    def ffmpeg(options: nil)
      Tempfile.open('concat_') do |f|
        @filelist.each do |i|
          f.write("#{i}\n")
          f.fsync
        end
        begin
          cmdline = %W[#{@paths[:ffmpeg]} -f concat -safe 0 -i #{f.path} -c copy]
          cmdline += options if options && options.is_a?(Array)
          cmdline << options if options && options.is_a?(String)
          cmdline << @outname
          Util.runprogram(cmdline)
        rescue Interrupt => e
          raise e
        else
          Util.runprogram(%W[#{@paths[:mkvpropedit]} --add-track-statistics-tags #{@outname}])
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

      Util.runprogram(command)
    end
  end
end
