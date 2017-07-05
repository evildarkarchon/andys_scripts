# frozen_string_literal: true

require 'pathname'

require 'filemagic'

module Util
  def self.media_file?(list)
    whitelist = %w[video/x-flv video/mp4 video/mp2t video/3gpp video/quicktime video/x-msvideo video/x-ms-wmv video/webm video/x-matroska video/3gpp2 audio/x-wav]
    whitelist += %w[audio/wave video/dvd video/mpeg application/vnd.rn-realmedia-vbr audio/vnd.rn-realaudio audio/x-realaudio]

    magic = FileMagic.new(:mime_type)

    raise TypeError unless list.respond_to?(:to_a) || list.is_a?(String) || list.is_a?(Pathname)

    list = list.to_a if list.respond_to?(:to_a)

    list.map! { |i| i.realpath.to_s if i.respond_to?(:realpath) } if list.respond_to?(:map!)

    list = list.realpath.to_s if !list.respond_to?(:map!) && list.respond_to?(:realpath)

    raise ValueError, 'All entries in the list must be files' unless (list.respond_to?(:all?) && list.all? { |f| File.file?(f) }) || (!list.respond_to?(:all?) && File.file?(list))

    list.map! { |f| magic.file(f) } if list.respond_to?(:map!)

    list = magic.file(list) if list.is_a?(String)

    magic.close

    out = list.all? { |f| whitelist.any? { |m| f == m } } if list.respond_to?(:all?)
    out = whitelist.any? { |m| list == m } unless list.respond_to?(:all?)
    out
  end
end
