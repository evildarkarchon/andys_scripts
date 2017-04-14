# frozen_string_literal: true

require 'pathname'

require_relative '../util/sort'
require_relative '../mood'
module YTDL
  def self.findfiles(directory, sort: true, pretend: false)
    out = directory.find.to_a
    puts Mood.neutral('Step 1:') if pretend

    out.keep_if(&:file?) if respond_to?(:keep_if)
    outtemp = Util.sort(out.map(&:to_s)) if sort
    out = outtemp.map { |i| Pathname.new(i) } if sort
    puts out.inspect if pretend
    puts Mood.neutral('No files found in this directory, will not do any statistics calculation, muxing, or playlist creation/modification.') if [out.nil?, out.empty?].any?
    exit if [out.nil?, out.empty?].any?
    out
  end
end
