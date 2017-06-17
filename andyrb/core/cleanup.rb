# frozen_string_literal: true

module AndyCore
  module Array
    module Cleanup
      def cleanup(unique: true)
        out = flatten
        out = compact
        out = uniq if unique
        out
      end

      def cleanup!(unique: true)
        flatten!
        compact!
        uniq! if unique
      end
    end
  end
end
