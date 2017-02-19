require 'json'
require 'digest'
require 'pathname'
require 'date'
require 'etc'
require 'naturalsorter'
require 'subprocess'

require_relative 'mood'
# rubocop disable:Metrics/MethodLength
module Util
  def self.hashfile(filelist)
    hashes = {}
    if filelist.respond_to?(:each)
      filelist.each do |file|
        filedata = File.read(file)
        sha256 = Digest::SHA256.new
        puts Mood.happy { "Calculating hash for #{file}" }
        sha256 << filedata
        hashes[file] = sha256.hexdigest
      end
    else
      filedata = File.read(filelist)
      sha256 = Digest::SHA256.new
      puts Mood.happy { "Calculating hash for #{filelist}" }
      sha256 << filedata
      hashes[filelist] = sha256.hexdigest
    end
    yield hashes if block_given?
    hashes
  end

  def self.block(&block) # Deprecated method that only serves to show what the & argument does.
    # yield if block_given?
    shutup = block
    raise 'Use a lambda or Proc instead.'
  end

  def self.recursive_symbolize_keys(my_hash)
    case my_hash
    when Hash
      Hash[
        my_hash.map do |key, value|
          [key.respond_to?(:to_sym) ? key.to_sym : key, recursive_symbolize_keys(value)]
        end
      ]
    when Enumerable
      my_hash.map { |value| recursive_symbolize_keys(value) }
    else
      my_hash
    end
  end

  def self.privileged?(user = 'root', path = nil)
    currentuser = Etc.getpwuid unless path
    value = false
    path &&= Pathname.new(path) unless path.is_a?(Pathname)
    privuser =
      case
      when user.respond_to?(:to_s) && !path
        Etc.getpwnam(user)
      when user.respond_to?(:to_i) && !path
        Etc.getpwuid(user.to_i)
      end
    # value = true if currentuser.uid == privuser.uid && !path
    # value = true if path && path.respond_to?(:writable?) && path.writable?
    value =
      case
      when path && path.respond_to?(:writable?) && path.writable?, currentuser.uid == privuser.uid && !path
        true
      end
    yield value if block_given?
    value
  end

  def self.class_exists?(name)
    klass = Module.const_get(name)
    klass.is_a?(Class) unless klass.is_a?(Module)
    klass.is_a?(Module) if klass.is_a?(Module)
    false unless klass.is_a?(Module) || klass.is_a?(Module)
  rescue NameError
    false
  end
  # Convenience class for writing or printing pretty JSON.
  class GenJSON
    def initialize(input, pretty = true)
      raise 'Input must be able to be converted to a JSON string.' unless input.respond_to?(:to_json)
      @output = JSON.pretty_generate(JSON.parse(input.to_json)) if pretty
      @output = input.to_json unless pretty
    end

    def write(filename)
      File.open(filename, 'w') { |of| of.write(@output) }
    end

    def output
      yield @output if block_given?
      @output
    end
  end

  class FindApp
    def self.which(cmd)
      exe = nil
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          which = File.join(path, "#{cmd}#{ext}")
          exe = which if File.executable?(which) && !File.directory?(which)
        end
      end
      yield exe if block_given?
      exe
    end
  end

  # Calculates the difference between dates from specified timestamp to now.
  # Params:
  # +timestamp+:: A timestamp that is either a Time object or a number of seconds from unix epoch.
  class DateDiff
    def self.getdiff(timestamp)
      now = Date.today
      # than = timestamp.to_date if timestamp.is_a?(Time)
      # than = Time.at(timestamp).to_date unless than.nil? || than.is_a?(Date)
      raise 'timestamp must be a Date or Time object or any object convertable to an integer.' unless timestamp.is_a?(Date) || timestamp.is_a?(Time) || timestamp.respond_to?(:to_i)
      than =
        case
        when timestamp.is_a?(Time)
          timestamp.to_date
        when !timestamp.is_a?(Date) && !timestamp.is_a?(Time) && timestamp.respond_to?(:to_i)
          Time.at(timestamp.to_i).to_date
        when timestamp.is_a?(Date)
          timestamp
        end
      diff = now - than
      yield diff if block_given?
      diff.to_i if diff.respond_to?(:to_i) && !block_given?
    end
  end

  # Class to sort the entries in a given variable.
  # Params:
  # +input+:: The data that will be sorted.
  class SortEntries
    def self.sort(input)
      input = input.to_a if input.respond_to?(:to_a)
      begin
        sorted = Naturalsorter::Sorter.sort(input, true)
      rescue NameError
        sorted = input
        sorted.sort_by! { |m| m.group.name.downcase }
      end
      yield sorted if block_given?
      sorted
    end
  end

  class Program
    def self.runprogram(program, use_sudo = false, sudo_user = nil, parse_output = false)
      raise 'Program argument blank and no block given.' unless block_given? || program
      cmdline = []
      # sudo_user = 'root' if use_sudo && !sudo_user
      # cmdline << ['sudo', '-u', sudo_user] if use_sudo
      raise 'Program variable is not an array or convertable into an array' unless program.is_a?(Array) || program.respond_to?(:to_a)
      program = program.to_a unless program.is_a?(Array)
      cmdline << %W(sudo -u #{sudo_user}) if use_sudo && sudo_user
      cmdline << %w(sudo) if use_sudo && !sudo_user
      cmdline << program
      cmdline.flatten!
      cmdline.compact!
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

class Object
  def in?(*arr)
    arr.flatten! if arr.respond_to?(:flatten!)
    arr.uniq! if arr.respond_to?(:uniq!)
    arr.include? self
  end
end
