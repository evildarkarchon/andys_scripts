# frozen_string_literal: true

require 'json'

module Util
  # Convenience class for writing or printing pretty JSON.
  class GenJSON
    def initialize(input, pretty: true)
      raise 'Input must be able to be converted to a JSON string.' unless input.respond_to?(:to_json)
      @output = pretty ? JSON.pretty_generate(JSON.parse(input.to_json)) : input.to_json
      # @output = JSON.pretty_generate(JSON.parse(input.to_json)) if pretty
      # @output = input.to_json unless pretty
    end

    def write(filename)
      # File.open(filename, 'w') { |of| of.write(@output) }
      IO.write(filename, @output)
    end

    def output
      yield @output if block_given?
      @output
    end
  end
end
