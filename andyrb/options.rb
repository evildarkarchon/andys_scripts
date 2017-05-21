# frozen_string_literal: true

require 'optparse'

class Options
  attr_reader :source, :args
  def initialize(sourceargs, opthash = nil)
    raise ValueError, 'You must supply either a code block or a hash.' unless block_given? || opthash
    @args = {}
    yield @args if block_given? && !opthash
    @args = opthash if opthash && !block_given?
    raise TypeError, '@args must be either a hash or nil' unless @args.is_a?(Hash) || @args.nil?
    @source = sourceargs.is_a?(String) ? sourceargs.to_a : sourceargs
  end

  def parse_args!
    optparse = OptionParser.new
    raise 'A block must be passed to this method.' unless block_given?
    yield optparse, @args if block_given?
    optparse.parse!(@source)
  end

  def construct!
    raise 'The construct! method is obsolete, use parse_args!'
  end

  def [](key)
    hash = { source: @source, args: @args }
    hash[key]
  end

  def inspect
    "Options<@source = #{@source}, @args = #{@args}>"
  end

  def to_h
    { source: @source, args: @args }
  end

  def +(other)
    @args + other
  end

  def -(other)
    @args - other
  end

  def <<(obj)
    @args << obj
  end

  def <=>(other)
    @args <=> other
  end

  def ==(other)
    @args == other
  end

  def &(other)
    @args & other
  end
end
