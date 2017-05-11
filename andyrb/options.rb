# frozen_string_literal: true

require 'optparse'

class Options
  attr_reader :source, :args
  def initialize(sourceargs, opthash = nil)
    @args = {}
    yield @args if block_given? && !opthash
    @args = opthash if opthash && !block_given?
    raise TypeError, '@args must be either a hash or nil' unless @args.is_a?(Hash) || @args.nil?
    raise ValueError, 'You must supply either a code block or a hash.' unless block_given? || opthash
    @source = sourceargs
  end

  def construct!
    optparse = OptionParser.new
    yield optparse, @args
    optparse.parse!(@source)
  end

  def inspect
    "Options<@source = #{@source}, @args = #{@args}>"
  end

  def to_h
    { source: @source, args: @args }
  end
end
