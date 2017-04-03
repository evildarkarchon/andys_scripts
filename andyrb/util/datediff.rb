# frozen_string_literal: true

require 'date'

module Util
  def self.datediff(timestamp)
    now = Date.today
    # than = timestamp.to_date if timestamp.is_a?(Time)
    # than = Time.at(timestamp).to_date unless than.nil? || than.is_a?(Date)
    raise 'timestamp must be a Date or Time object or any object convertable to an integer.' unless timestamp.is_a?(Date) || timestamp.is_a?(Time) || timestamp.respond_to?(:to_i)
    than =
      case
      when timestamp.is_a?(Time)
        timestamp.to_date
      when !timestamp.is_a?(Date) && !timestamp.is_a?(Time) && timestamp.respond_to?(:to_i)
        Time.at(timestamp.to_i).to_date
      when timestamp.is_a?(Date)
        timestamp
      end
    diff = now - than
    yield diff.to_i if diff.respond_to?(:to_i) && block_given?
    diff.to_i if diff.respond_to?(:to_i) && !block_given?
  end
end
