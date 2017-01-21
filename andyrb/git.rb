require 'subprocess'
require 'fileutils'
require 'pathname'

require_relative 'mood'
require_relative 'util'
class Git
  attr_reader :use_sudo, :sudo_user, :wd, :wdpath
  def initialize(wd, use_sudo = false, sudo_user = 'root')
    @use_sudo = use_sudo
    @sudo_user = sudo_user
    @wdpath = Pathname.new(wd)
    @wd = wd
    @wdlock = @wdpath + '.git/index.lock'

    case
    when !@use_sudo && @sudo_user && !Util.privileged?(@sudo_user)
      @use_sudo = true
      puts Mood.neutral('use_sudo was not set properly, defaulting to root, fix the code asap.')
    when @use_sudo && !@sudo_user
      @sudo_user = 'root'
      puts Mood.neutral('sudo_user was not set properly, defaulting to root, fix the code asap.')
    when !@wdpath.parent.writable? && !@wdpath.writable? && !@use_sudo
      @use_sudo = true
      @sudo_user = 'root'
      puts Mood.neutral('Working directory is not writable, sudo forced.')
    end
  end

  def clean_lock
    case
    when @use_sudo && @wdlock.exist?
      Util::Program.runprogram(%W(rm #{@wdlock}), use_sudo: true, sudo_user: @sudo_user)
    when !@use_sudo && @wdlock.exist?
      @wdlock.delete
    end
  end

  def clone(url)
    Util::Program.runprogram(%W(git clone #{url} #{@wd}), use_sudo: @use_sudo, sudo_user: @sudo_user)
  end

  def gc(aggressive = false)
    Util::Program.runprogram(%w(git gc --aggressive), use_sudo: @use_sudo, sudo_user: @sudo_user) if aggressive
    Util::Program.runprogram(%w(git gc), use_sudo: @use_sudo, sudo_user: @sudo_user) unless aggressive
  end

  def pull
    Dir.chdir(@wd)
    Util::Program.runprogram(%w(git pull), use_sudo: @use_sudo, sudo_user: @sudo_user)
  end
end
