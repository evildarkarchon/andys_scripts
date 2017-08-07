# frozen_string_literal: true

require 'subprocess'
require 'fileutils'
require 'pathname'

require_relative 'mood'
require_relative 'util/program'
require_relative 'util/findapp'

class Git
  attr_reader :use_sudo, :sudo_user, :wd, :wdpath
  def initialize(wd, use_sudo: false, sudo_user: 'root', container: nil)
    @use_sudo = container ? true : use_sudo
    @sudo_user = container ? 'root' : sudo_user
    @wdpath = Pathname.new(wd)
    @wd = wd
    @wdlock = @wdpath + '.git/index.lock'
    @git = Util.findapp('git') do |loc|
      raise 'git not found.' unless loc
      raise 'git found, but is not executable' if loc && !File.executable?(loc)
      loc
    end
    @container = container
    @systemd = container ? true : false

    case
    when !@use_sudo && @sudo_user && !Util.privileged?(@sudo_user)
      @use_sudo = true
      puts Mood.neutral('use_sudo was not set properly, defaulting to enabled, fix the code asap.')
    when @use_sudo && !@sudo_user
      @sudo_user = 'root'
      puts Mood.neutral('sudo_user was not set properly, defaulting to root, fix the code asap.')
    when !@wdpath.exist? && !@wdpath.parent.writable? && !@use_sudo, @wdpath.exist? && !@wdpath.writable? && !@use_sudo
      @use_sudo = true
      @sudo_user = 'root'
      puts Mood.neutral('Working directory is not writable, sudo forced.')
    end
    @git.freeze
    @use_sudo.freeze
    @wdpath.freeze
    @wd.freeze
    @wdlock.freeze
    @container.freeze if @container
  end

  def clean_lock
    case
    when @container && @wdlock.exist?
      Util.runprogram(%W[rm #{@wdlock}], use_sudo: true, systemd: @systemd, container: @container)
    when @use_sudo && @wdlock.exist?
      Util.runprogram(%W[rm #{@wdlock}], use_sudo: true, sudo_user: @sudo_user)
    when !@use_sudo && @wdlock.exist?
      @wdlock.delete
    when !@use_sudo && !@wdlock.writable? && @sudo_user
      Util.runprogram(%W[rm #{@wdlock}], use_sudo: true, sudo_user: @sudo_user)
    when !@use_sudo && !@wdlock.writable? && !@sudo_user
      Util.runprogram(%W[rm #{@wdlock}], use_sudo: true)
    end
  end

  def clone(url)
    Util.runprogram(%W[#{@git} clone #{url} #{@wd}], use_sudo: @use_sudo, sudo_user: @sudo_user, systemd: @systemd, container: @container)
  end

  def gc(aggressive: false)
    aggressive.freeze
    gccmd = %W[#{@git} gc]
    gccmd << '--aggressive' if aggressive
    gccmd.freeze
    Util.runprogram(gccmd, use_sudo: @use_sudo, sudo_user: @sudo_user, systemd: @systemd, container: @container)
  end

  def pull
    Util.runprogram(%W[#{@git} pull], use_sudo: @use_sudo, sudo_user: @sudo_user, workdir: @wd, systemd: @systemd, container: @container)
  end
end
