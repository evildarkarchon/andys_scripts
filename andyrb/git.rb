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
    @wdlock = @wdpath.join('.git/index.lock')

    case
    when !@use_sudo && !Util.privileged?(@sudo_user)
      @use_sudo = true
      puts Mood.neutral('use_sudo was not set properly, defaulting to root, fix the code asap.')
    when @use_sudo && !@sudo_user
      @sudo_user = 'root'
      puts Mood.neutral('sudo_user was not set properly, defaulting to root, fix the code asap.')
    when !@wdpath.writable? && !@use_sudo
      @use_sudo = true
      @sudo_user = 'root'
      puts Mood.neutral('Working directory is not writable, sudo forced.')
    end
  end

  def clean_lock
    # @wdlock.delete unless @use_sudo && @wdlock.exist?
    # Util::Program.runprogram(['sudo', '-u', @sudo_user, 'rm', @wdlock.to_s]) if @use_sudo && @wdlock.exist?
    case
    when !@use_sudo && @wdlock.exist?
      @wdlock.delete
    when @use_sudo && @wdlock.exist?
      Util::Program.runprogram(%W(sudo -u #{@sudo_user} rm #{@wdlock}))
    end
  end

  def clone(url)
    # Util::Program.runprogram(['git', 'clone', url, @wd]) unless @use_sudo
    # Util::Program.runprogram(['sudo', '-u', @sudo_user, 'git', 'clone', url, @wd]) if @use_sudo
    case
    when @use_sudo
      Util::Program.runprogram(%W(sudo -u #{@sudo_user} git clone #{url} #{@wd}))
    else
      Util::Program.runprogram(%W(git clone #{url} #{@wd}))
    end
  end

  def gc(aggressive = false)
    case
    when !aggressive && !@use_sudo
      Util::Program.runprogram(%w(git gc))
    when aggressive && !@use_sudo
      Util::Program.runprogram(%w(git gc --aggressive))
    when @use_sudo && !aggressive
      # Util::Program.runprogram(['sudo', '-u', @sudo_user, 'git', 'gc'])
      Util::Program.runprogram(%W(sudo -u #{@sudo_user} git gc))
    when @use_sudo && aggressive
      # Util::Program.runprogram(['sudo', '-u', @sudo_user, 'git', 'gc', '--aggressive'])
      Util::Program.runprogram(%W(sudo -u #{@sudo_user} git gc --aggressive))
    end
  end

  def pull
    Dir.chdir(@wd)
    case
    when @use_sudo
      Util::Program.runprogram(%W(sudo -u #{@sudo_user} git pull))
    else
      Util::Program.runprogram(%w(git pull))
    end
  end
end
