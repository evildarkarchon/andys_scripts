# frozen_string_literal: true

require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'

module ConvertMkv
  class Mux
    def initialize(filelist, outdir, paths: nil, audio: false)
      @filelist = filelist
      @outdir = outdir.is_a?(Pathname) ? outdir : Pathname.new(outdir)
      @paths = paths ? paths : { ffmpeg: Util::FindApp.which('ffmpeg'), mkvmerge: Util::FindApp.which('mkvmerge'), mkvpropedit: Util::FindApp.which('mkvpropedit') }
      @audio = audio
    end

    def mkvmerge(options: nil)
      @filelist.each do |i|
        i = Pathname.new(i) unless i.is_a?(Pathname)
        cmdline = [@paths[:mkvmerge]]
        cmdline += options if options
        cmdline += @audio ? %W[-o #{@outdir.join(i.sub_ext('.mka').basename)} = #{i}] : %W[-o #{@outdir.join(i.sub_ext('.mkv').basename)} = #{i}]
        Util::Program.runprogram(cmdline)
      end
    end

    def ffmpeg(options: nil)
      @filelist.each do |i|
        i = Pathname.new(i) unless i.is_a?(Pathname)
        out = @audio ? @outdir.join(i.sub_ext('.mka').basename) : @outdir.join(i.sub_ext('.mkv').basename)
        cmdline = %W[#{@paths[:ffmpeg]} -i #{i} -c copy -hide_banner -y]
        cmdline += options if options && options.is_a?(Array)
        cmdline << options if options && options.is_a?(String)
        cmdline << out
        begin
          Util::Program.runprogram(cmdline)
        rescue Interrupt => e
          raise e
        else
          Util::Program.runprogram(%W[#{@paths[:mkvpropedit]} --add-track-statistics-tags #{out}])
        end
      end
    end
  end
end
