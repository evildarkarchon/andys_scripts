require 'termcolor'
# Convenience methods to add a colored star based on the "mood" method called.
module Mood
  def self.happy
    "<green>*</green> #{yield}".termcolor
  end

  def self.neutral
    "<yellow>*</yellow> #{yield}".termcolor
  end

  def self.sad
    "<red>*</red> #{yield}".termcolor
  end

  def self.colorful(color)
    colorful = "<#{color}>*</#{color}>".termcolor
    yield colorful
  end
end
