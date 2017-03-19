# frozen_string_literal: true
require 'termcolor'
# Convenience methods to add a colored star based on the "mood" method called.
module Mood
  def self.happy(message = nil)
    message = yield if block_given? && message.nil?
    "<green>*</green> #{message}".termcolor
  end

  def self.neutral(message = nil)
    message = yield if block_given? && message.nil?
    "<yellow>*</yellow> #{message}".termcolor
  end

  def self.sad(message = nil)
    message = yield if block_given? && message.nil?
    "<red>*</red> #{message}".termcolor
  end

  def self.colorful(color, message = nil)
    message = yield if block_given? && !message
    "<#{color}>*<#{color}> #{message}".termcolor
  end
end
