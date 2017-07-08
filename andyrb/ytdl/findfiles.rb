# frozen_string_literal: true

require 'pathname'

require_relative '../core/sort'
require_relative '../core/monkeypatch'
require_relative '../mood'

# Array.private_method_defined?(:include) ? Array.send(:include, AndyCore::Aray::NatSort) : Array.include(AndyCore::Array::NatSort)
AndyCore.monkeypatch(Array, AndyCore::Array::NatSort)

module YTDL
  def self.findfiles(directory, sort: true, pretend: false)
    directory = Pathname.new(directory) unless directory.is_a?(Pathname)

    out = directory.find.to_a
    puts Mood.neutral('Step 1:') if pretend

    out.keep_if(&:file?) if respond_to?(:keep_if)
    outtemp = out.natsort if sort
    out = outtemp.map { |i| Pathname.new(i) } if sort
    puts out.inspect if pretend
    puts Mood.neutral('No files found in this directory, will not do any statistics calculation, muxing, or playlist creation/modification.') if out.nil? || out.empty?
    exit if out.nil? || out.empty?
    out
  end
end
