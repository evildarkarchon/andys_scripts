# frozen_string_literal: true

require 'childprocess'
require 'backticks'

require_relative '../core/cleanup'
require_relative '../core/monkeypatch'
require_relative '../mood'

AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)

module Util
  def self.runprogram(program, use_sudo: false, sudo_user: nil, parse_output: false, workdir: nil, systemd: false, container: nil)
    cmdline = []
    use_sudo = true if container
    out = nil

    raise 'Program variable is not an array or convertable into an array' unless program.is_a?(Array) || program.respond_to?(:to_a)
    program = program.to_a unless program.is_a?(Array)
    program.freeze
    cmdline << %W[sudo -u #{sudo_user}] if use_sudo && sudo_user && !container
    cmdline << %w[sudo] if [use_sudo && !sudo_user, container].any?
    cmdline << %w[systemd-run -t] if systemd || container
    cmdline << %W[--machine=#{container}] if container
    cmdline << %W[-p User=#{sudo_user}] if systemd && sudo_user
    cmdline << program
    cmdline.cleanup!(unique: false)
    cmdline.freeze
    begin
      if !parse_output
        process = ChildProcess.build(*cmdline)
        process.cwd = workdir if workdir
        process.io.inherit! unless parse_output
        process.start
        process.wait while process.alive?
      else
        out = Backticks.run(*cmdline)
        out = out&.chomp
      end
    rescue Interrupt => e
      raise e
    else
      yield out if block_given? && parse_output
      out if parse_output
    end
  end
  class Program
    def self.runprogram(program, use_sudo: false, sudo_user: nil, parse_output: false, workdir: nil, systemd: false, container: nil)
      puts Mood.neutral('The Program class is being deprecated, use Util.runprogram instead')
      Util.runprogram(program, use_sudo: use_sudo, sudo_user: sudo_user, parse_output: parse_output, workdir: workdir, systemd: systemd, container: container)
    end
  end
end
