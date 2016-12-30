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

  def self.block(*args, **kwargs) # Convenience method to quickly make code blocks.
    yield args unless !defined?(args) || args.nil? || args.empty?
    yield kwargs unless !defined?(kwargs) || kwargs.nil? || kwargs.empty?
    yield if kwargs.empty? && args.empty?
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
  # Convenience class for writing or printing pretty JSON.
  class GenJSON
    attr_reader :output
    def initialize(input, pretty = true)
      raise 'Input must be able to be converted to a JSON string.' unless input.respond_to?(:to_json)
      @output = JSON.parse(input.to_json)
      @output = JSON.pretty_generate(@output) if pretty
      @output = input.to_json unless pretty
    end

    def write(filename)
      outputfile = open(filename, 'w')
      outputfile.write(@output)
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
      than = timestamp.to_date if timestamp.is_a?(Time)
      than = Time.at(timestamp).to_date unless than.nil? || than.is_a?(Date)
      diff = now - than
      return diff.to_i if diff.respond_to?(:to_i) && !block_given?
      yield diff if block_given?
    end
  end

  def self.privileged?(user = 'root')
    currentuser = Etc.getpwuid
    privuser = nil
    value = false
    if user.respond_to?(:to_s)
      privuser = Etc.getpwnam(user)
    elsif user.respond_to?(:to_i)
      privuser = Etc.getpwuid(user.to_i)
    end
    value = true if currentuser.uid == privuser.uid
    yield value if block_given?
    value
  end

  # Class to sort the entries in a given variable.
  # Params:
  # +input+:: The data that will be sorted.
  class SortEntries
    def self.sort(input)
      unsorted = input.to_a if input.respond_to?(:to_a)
      sorted = nil
      begin
        sorted = Naturalsorter::Sorter.sort(unsorted, true)
      rescue NameError
        sorted = unsorted
        sorted.sort_by! { |m| m.group.name.downcase }
      end
      yield sorted if block_given?
      sorted
    end
  end

  class Program
    def self.runprogram(program, use_sudo = false, sudo_user = nil, parse_output = false)
      cmdline = []
      sudo_user = 'root' if use_sudo && !sudo_user
      cmdline << ['sudo', '-u', sudo_user] if use_sudo
      cmdline << program
      cmdline.flatten!
      cmdline.compact!
      output = nil
      begin
        Subprocess.check_call(cmdline) unless parse_output
        output = Subprocess.check_output(cmdline) if parse_output
      rescue Interrupt
        exit 1
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
