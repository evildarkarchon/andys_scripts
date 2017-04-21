# frozen_string_literal: true

require 'naturalsorter'

module AndyCore
  module Array
    module NatSort
      def natsort
        out = dup.map!(&:to_s)
        out = Naturalsorter::Sorter.sort(out, true)
      rescue NameError
        dup.sort
      else
        out
      end

      def natsort!
        replace(natsort)
      end
    end
  end
end
