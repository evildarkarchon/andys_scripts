# frozen_string_literal: true

require 'subprocess'

require_relative '../core/cleanup'

Array.include AndyCore::Array::Cleanup unless Array.private_method_defined? :include
Array.send(:include, AndyCore::Array::Cleanup) if Array.private_method_defined? :include

module Util
  class Program
    def self.runprogram(program, use_sudo: false, sudo_user: nil, parse_output: false, workdir: nil)
      cmdline = []

      Dir.chdir(workdir) if workdir

      raise 'Program variable is not an array or convertable into an array' unless program.is_a?(Array) || program.respond_to?(:to_a)
      program = program.to_a unless program.is_a?(Array)
      program.freeze
      cmdline << %W[sudo -u #{sudo_user}] if use_sudo && sudo_user
      cmdline << %w[sudo] if use_sudo && !sudo_user
      cmdline << program
      cmdline.cleanup!(unique: false)
      cmdline.freeze
      begin
        Subprocess.check_call(cmdline) unless parse_output
        output = Subprocess.check_output(cmdline) if parse_output
      rescue Subprocess::NonZeroExit, Interrupt => e
        raise e
      else
        yield output if block_given? && output
        output ? output : nil
      end
    end
  end
  class << Program
    alias run runprogram
  end
end
