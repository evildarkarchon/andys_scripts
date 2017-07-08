# frozen_string_literal: true

require 'json'
require 'pathname'

require_relative '../util/program'
require_relative '../util/findapp'
require_relative '../util/recursive_symbolize_keys'

module VideoInfo
  def self.probe(filepath, verbose: false)
    raise 'First argument must be either a string or a pathname' unless filepath.is_a?(String) || filepath.is_a?(Pathname)
    out = nil
    filepath = Pathname.new(filepath) unless filepath.is_a?(Pathname)
    filepath.freeze unless frozen?
    puts Mood.happy("Extracting metadata from #{filepath.basename}") if verbose
    Util.findapp('ffprobe') do |fp|
      cmd = %W[#{fp} -i #{filepath.realpath} -hide_banner -of json -show_streams -show_format]
      cmd << %w[-loglevel quiet] unless verbose
      out = Util::Program.runprogram(cmd, parse_output: true).to_s
    end
    out = Util.recursive_symbolize_keys(JSON.parse(out))
    out.freeze
    yield out if block_given?
    out
  end
end
