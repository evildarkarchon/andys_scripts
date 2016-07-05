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
        # hmac = OpenSSL::HMAC.new(filedata, OpenSSL::Digest::SHA256.new)
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
      # puts hashes
    end
    yield hashes if block_given?
    hashes
  end

  def self.block(*args, **kwargs)
    yield args unless !defined?(args) || args.nil? || args.empty?
    yield kwargs unless !defined?(kwargs) || kwargs.nil? || kwargs.empty?
    yield if kwargs.empty? && args.empty?
  end
  # Convenience class for writing or printing pretty JSON.
  class GenJSON
    # Generates pretty JSON and writes it to a file.
    # Params:
    # +filename+:: Name of the file to write to.
    # +inputhash+:: hash that will be converted to JSON.
    def self.write(filename, inputhash)
      input = inputhash.to_h if inputhash.respond_to?(:to_h)
      outputfile = open(filename, 'w')
      outputfile.write(JSON.pretty_generate(input))
    end

    # Generates pretty JSON and prints it to stdout.
    # Params:
    # +inputhash+:: Hash that will be converted to JSON
    def self.print(inputhash)
      input = inputhash.to_h if inputhash.respond_to?(:to_h)
      puts JSON.pretty_generate(input)
    end
  end

  class FindApp
    # Cross-platform way of finding an executable in the $PATH.
    #
    #   which('ruby') #=> /usr/bin/ruby
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
      return diff.to_i if diff.respond_to?(:to_i)
      yield diff if block_given?
      diff
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
    def self.runprogram(program, use_sudo = false, sudo_user = nil)
      cmdline = []
      sudo_user = 'root' if use_sudo && !sudo_user
      cmdline << ['sudo', '-u', sudo_user] if use_sudo
      cmdline << program
      cmdline.flatten!
      Subprocess.check_call(cmdline)
    end
  end
  class << Program
    alias run runprogram
  end
end

class Object
  def in?(*arr)
    # print arr
    # print "\n"
    # print self
    # print "\n"
    # arr = arr[0] if arr[0].respond_to?(:each) && arr.respond_to?(:length) && arr.length == 1
    arr.flatten! if arr.respond_to?(:flatten!)
    arr.uniq! if arr.respond_to?(:uniq!)
    # print("#{arr}\n")
    arr.include? self
  end
end
