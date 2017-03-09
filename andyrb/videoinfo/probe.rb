require 'json'
require 'pathname'

require_relative '../util/program'

module VideoInfo
  def self.probe(filepath, verbose: false)
    raise 'First argument must be either a string or a pathname' unless filepath.is_a?(String) || filepath.is_a?(Pathname)
    out = nil
    filepath = Pathname.new(filepath) unless filepath.is_a?(Pathname)
    puts Mood.happy("Extracting metadata from #{filepath.basename}") if verbose
    Util::FindApp.which('ffprobe') do |fp|
      raise 'ffprobe not found' unless fp
      raise 'ffprobe found, but is not executable' if fp && !File.executable?(fp)
      cmd = %W(#{fp} -i #{filepath.realpath} -hide_banner -of json -show_streams -show_format -loglevel quiet)
      out = Util::Program.runprogram(cmd, parse_output: true).to_s
    end
    out = JSON.parse(out)
    yield out if block_given?
    out
  end
end
