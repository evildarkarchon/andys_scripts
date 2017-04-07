# frozen_string_literal: true

require_relative 'cleanup'
Array.include AndyCore::Array::Cleanup

module AndyCore
  module Object
    def in?(*arr)
      arr.cleanup!
      arr.include? self
    end
  end
end
