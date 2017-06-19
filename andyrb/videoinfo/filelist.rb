# frozen_string_literal: true

require 'filemagic'

require_relative '../core/sort'
require_relative '../core/monkeypatch'

AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

module VideoInfo
  def self.genfilelist(filelist, testmode: false, sort: true)
    raise 'filelist must be an array or convertable to an array' unless filelist.respond_to?(:to_a)
    whitelist = %w[video/x-flv video/mp4 video/mp2t video/3gpp video/quicktime video/x-msvideo video/x-ms-wmv video/webm video/x-matroska video/3gpp2 audio/x-wav]
    whitelist += %w[audio/wave video/dvd video/mpeg application/vnd.rn-realmedia-vbr audio/vnd.rn-realaudio audio/x-realaudio]
    magic = FileMagic.new(:mime_type)
    filelist.natsort! if sort
    puts 'Files to be examined:' if testmode
    filelist.keep_if { |f| whitelist.include?(magic.file(f)) } unless testmode
    case
    when testmode
      testlist = {}
      filelist.each do |f|
        mime = magic.file(f)
        testlist[File.basename(f).to_sym] = { mimetype: mime, whitelisted: whitelist.include?(mime) } if f.respond_to?(:to_sym)
        testlist[File.basename(f)] = { mimetype: mime, whitelisted: whitelist.include?(mime) } unless f.respond_to?(:to_sym)
      end
      puts testlist
    end
    magic.close
    yield filelist if block_given?
    filelist
  end
end
