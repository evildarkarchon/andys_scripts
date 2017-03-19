# frozen_string_literal: true
require 'subprocess'

require_relative '../core/cleanup'

module Util
  class Program
    def self.runprogram(program, use_sudo: false, sudo_user: nil, parse_output: false)
      cmdline = []
      # sudo_user = 'root' if use_sudo && !sudo_user
      # cmdline << ['sudo', '-u', sudo_user] if use_sudo
      raise 'Program variable is not an array or convertable into an array' unless program.is_a?(Array) || program.respond_to?(:to_a)
      program = program.to_a unless program.is_a?(Array)
      cmdline << %W(sudo -u #{sudo_user}) if use_sudo && sudo_user
      cmdline << %w(sudo) if use_sudo && !sudo_user
      cmdline << program
      cmdline.cleanup!(unique: false)
      output = nil
      begin
        Subprocess.check_call(cmdline) unless parse_output
        output = Subprocess.check_output(cmdline) if parse_output
      rescue Subprocess::NonZeroExit, Interrupt => e
        raise e
      else
        yield output if block_given? && output
        output if output
      end
    end
  end
  class << Program
    alias run runprogram
  end
end
