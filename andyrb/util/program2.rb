# frozen_string_literal: true

require 'subprocess'

require_relative '../core/cleanup'
require_relative '../core/monkeypatch'

AndyCore.monkeypatch(Array, AndyCore::Array::Cleanup)

module Util
  class Program
    def initialize(program: nil, use_sudo: false, sudo_user: nil, parse_output: false, workdir: nil, systemd: false, container: nil)
      self.workdir = workdir
      self.parse_output = parse_output
      self.cmdline = block_given? ? yield : []
      self.cmdline += %W[sudo -u #{sudo_user}] if use_sudo && sudo_user && !block_given?
      self.cmdline += %w[sudo] if use_sudo && !sudo_user && !block_given?
      self.cmdline += %w[systemd-run -t] if systemd && !container && !use_sudo && !block_given?
      self.cmdline += %w[sudo systemd-run -t] if systemd && container && !use_sudo && !block_given?
      self.cmdline += %W[--machine=#{container}] if systemd && container && !block_given?
      self.cmdline += %W[-p User=#{sudo_user}] if systemd && container && !use_sudo && sudo_user && !block_given?
      self.cmdline << program unless block_given?
      self.cmdline.cleanup!(unique: false)
      self.cmdline.freeze
    end

    def runprogram
      Dir.chdir(workdir) if workdir
      begin
        Subprocess.check_call(self.cmdline) unless parse_output
        output = Subprocess.check_output(self.cmdline) if parse_output
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
