# frozen_string_literal: true

require 'filemagic'

require_relative '../core/sort'
require_relative '../core/monkeypatch'
require_relative '../util/media_file'

AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

module VideoInfo
  def self.genfilelist(filelist, testmode: false, sort: true)
    raise 'filelist must be an array or convertable to an array' unless filelist.respond_to?(:to_a)
    filelist.natsort! if sort
    puts 'Files to be examined:' if testmode
    filelist.keep_if { |f| Util.media_file?(f) } unless testmode
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
    yield filelist if block_given?
    filelist
  end
end
