require 'termcolor'
# rubocop:disable Style/BlockComments
module Mood
=begin
'Convenience class to add a colored star based on the "mood" method called.'
=end

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
