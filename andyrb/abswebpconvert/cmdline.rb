# frozen_string_literal: true

require 'pathname'
require 'filemagic'

require_relative '../core/cleanup'
require_relative '../util/findapp'
Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::Cleanup) : Array.include(AndyCore::Array::Cleanup)

module ABSWebPConvert
  class Command
    attr_reader :list, :outpath, :filepath
    def initialize(filename, outdir, mode, quality, explicit: false, verbose: false)
      @filepath = Pathname.new(filename).realpath.freeze
      ext = @filepath.extname.downcase.freeze
      magic = FileMagic.new(:mime_type)
      @outpath = Pathname.new(outdir).realpath + Pathname.new(filepath.basename.to_s).sub_ext('.webp').to_s.freeze

      lossless_mime = %w[image/png image/gif image/tiff image/x-pcx application/tga application/x-tga application/x-targs image/tga image/x-tga image/targa image/x-targa image/vnd.adobe.photoshop].cleanup!(unique: false).freeze

      raw = %w[.3fr .ari .arw .srf .sr2 .bay .crw .cr2 .cap .iiq .eip .dcs .dcr .drf .k25 .kdc .dng .erf .fff .mef .mdc .mos .mrw]
      raw += %w[.nef .nrw .orf .pef .ptx .pxn .r3d .raf .raw .rw2 .rwl .rwz .srw .x3f]
      raw.cleanup!(unique: false).freeze

      # lossless = ['-define', 'webp:lossless=true']
      lossless = %w[-define webp:lossless=true].freeze
      # lossymode = Args.lossy
      # losslessmode = Args.lossless
      # if (lossless_mime.include?(magic.file(@filepath.to_s)) || raw.include?(ext)) && !outmode == 'lossy'
      if [[lossless_mime.include?(magic.file(@filepath.to_s)), raw.include?(ext)].any?, !explicit].all?
        mode = 'lossless'
      end

      Util::FindApp.which('convert') do |c|
        raise 'convert not found or is not executable.' unless c && File.executable?(c)
        @list = %W[#{c} #{filepath}]
        @list << %W[-quality #{quality}]
        @list << lossless if mode == 'lossless'
        @list << %w[-define webp:thread-level=1]
        @list << '-verbose' if verbose
        @list << @outpath.to_s
        @list.cleanup!(unique: false)
        @list.freeze
      end
    end
  end
end
