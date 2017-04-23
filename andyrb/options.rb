# frozen_string_literal: true

require 'optparse'

class Options
  attr_reader :source
  attr_accessor :args
  def initialize(source, opthash = nil)
    @args = {}
    @args = yield if block_given? && !opthash
    @args = opthash if opthash && !block_given?
    raise TypeError, '@args must be either a hash or nil' unless @args.is_a?(Hash) || @args.nil?
    @source = source
  end

  def construct!
    optparse = OptionParser.new
    yield optparse, @args
    optparse.parse!(@source)
  end
end
