# frozen_string_literal: true

# require 'json'
# require 'digest'
# require 'openssl'
# require 'pathname'
# require 'date'
# require 'etc'
# require 'naturalsorter'
# require 'subprocess'

# rubocop disable:Metrics/MethodLength
module Util
  require_relative 'util/hashfile'

  require_relative 'util/recursive_symbolize_keys'

  require_relative 'util/privileged'

  require_relative 'util/class_exists'

  require_relative 'util/sort'

  require_relative 'util/genjson'

  require_relative 'util/findapp'

  require_relative 'util/datediff'

  require_relative 'util/program'

  # Calculates the difference between dates from specified timestamp to now.
  # Params:
  # +timestamp+:: A timestamp that is either a Time object or a number of seconds from unix epoch.
  class DateDiff
    def self.getdiff(timestamp) # rubocop:disable Lint/UnusedMethodArgument
      #   now = Date.today
      #   than = timestamp.to_date if timestamp.is_a?(Time)
      #   than = Time.at(timestamp).to_date unless than.nil? || than.is_a?(Date)
      #   raise 'timestamp must be a Date or Time object or any object convertable to an integer.' unless timestamp.is_a?(Date) || timestamp.is_a?(Time) || timestamp.respond_to?(:to_i)
      #   than =
      #     case
      #     when timestamp.is_a?(Time)
      #       timestamp.to_date
      #     when !timestamp.is_a?(Date) && !timestamp.is_a?(Time) && timestamp.respond_to?(:to_i)
      #       Time.at(timestamp.to_i).to_date
      #     when timestamp.is_a?(Date)
      #       timestamp
      #    end
      #   diff = now - than
      #   yield diff.to_i if diff.respond_to?(:to_i) && block_given?
      #   diff.to_i if diff.respond_to?(:to_i) && !block_given?
      raise 'Use Util.datediff instaead.'
    end
  end

  # Class to sort the entries in a given variable.
  # This class is deprecated.
  # Params:
  # +input+:: The data that will be sorted.
  class SortEntries
    def self.sort(input)
      input = input.to_a if input.respond_to?(:to_a)
      raise 'Use Util.sort instead.'
    end
  end
end
