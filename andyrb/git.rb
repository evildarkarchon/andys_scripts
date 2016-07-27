require 'subprocess'
require 'fileutils'
require 'pathname'

require_relative 'mood'
require_relative 'util'
class Git
  attr_reader :use_sudo, :sudo_user, :wd, :wdpath
  attr_accessor :aggressive
  def initialize(wd, use_sudo = false, sudo_user = 'root')
    @use_sudo = use_sudo
    @sudo_user = sudo_user
    @wdpath = Pathname.new(wd)
    @aggressive = false
    @wd = wd
    wdlock = @wdpath.join('.git/index.lock')

    if !@use_sudo && !Util.privileged?(@sudo_user)
      @use_sudo = true
      puts Mood.neutral { 'use_sudo was not set properly, defaulting to root, fix the code asap.' }
    end

    if @use_sudo && !@sudo_user
      @sudo_user = 'root'
      puts Mood.neutral { 'sudo_user was not set properly, defaulting to root, fix the code asap.' }
    end
  end

  def clean_lock
    if wdlock.exist?
      wdlock.delete unless @use_sudo
      Util::Program.runprogram(['sudo', '-u', @sudo_user, 'rm', wdlock.to_s]) if @use_sudo
    end
  end
end
