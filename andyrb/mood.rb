# frozen_string_literal: true

require 'paint'
# Convenience methods to add a colored star based on the "mood" method called.
module Mood
  def self.happy(message = nil)
    message = yield if block_given? && message.nil?
    Paint['*', :green] + ' ' + message
  end

  def self.neutral(message = nil)
    message = yield if block_given? && message.nil?
    Paint['*', :yellow] + ' ' + message
  end

  def self.sad(message = nil)
    message = yield if block_given? && message.nil?
    Paint['*', :red] + ' ' + message
  end

  def self.colorful(color, message = nil)
    message = yield if block_given? && !message
    Paint['*', color.to_sym] + ' ' + message
  end

  class << self
    def [](color, message = nil)
      Paint['*', color.to_sym] + ' ' + message
    end
  end
end
