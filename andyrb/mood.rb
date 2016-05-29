require 'termcolor'
# Convenience methods to add a colored star based on the "mood" method called.
module Mood
  def self.happy(inputstring)
    ['<green>*</green>', inputstring].join(' ').termcolor
  end

  def self.neutral(inputstring)
    ['<yellow>*</yellow>', inputstring].join(' ').termcolor
  end

  def self.sad(inputstring)
    ['<red>*</red>', inputstring].join(' ').termcolor
  end
end
