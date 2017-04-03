# frozen_string_literal: true

require 'naturalsorter'

module Util
  def self.sort(input)
    input = input.to_a if input.respond_to?(:to_a)
    begin
      sorted = Naturalsorter::Sorter.sort(input, true)
    rescue NameError
      sorted = input
      sorted.sort_by! { |m| m.group.name.downcase }
    end
    yield sorted if block_given?
    sorted
  end
end
