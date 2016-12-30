require 'termcolor'
# Convenience methods to add a colored star based on the "mood" method called.
module Mood
  def self.happy(message = nil)
    out = nil
    out = "<green>*</green> #{message}".termcolor unless block_given?
    out = "<green>*</green> #{yield}".termcolor if block_given?
    out
  end

  def self.neutral(message = nil)
    out = nil
    out = "<yellow>*</yellow> #{message}".termcolor unless block_given?
    out = "<yellow>*</yellow> #{yield}".termcolor if block_given?
    out
  end

  def self.sad(message = nil)
    out = nil
    out = "<red>*</red> #{message}".termcolor unless block_given?
    out = "<red>*</red> #{yield}".termcolor if block_given?
    out
  end

  def self.colorful(color, message = nil)
    colorful = nil
    colorful = "<#{color}>*</#{color}> #{message}".termcolor unless block_given?
    colorful = "<#{color}>*</#{color}> #{yield}".termcolor if block_given?
    colorful
  end
end
