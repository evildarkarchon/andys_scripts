require 'json'
require 'digest'
require 'pathname'
require 'date'
require 'etc'
require 'naturalsorter'

require_relative 'mood'
# rubocop disable:Metrics/MethodLength
module Util
  # Convenience function to write json to a file.
  class GenJSON
    def self.write(filename, inputhash)
      input = ''
      if inputhash.respond_to?(:to_h)
        input = inputhash.to_h
      else
        input = inputhash
      end

      outputfile = open(filename, 'w')
      outputfile.write(json.pretty_generate(input))
    end
  end
  # Convenience function to calculate hashes on a file or a list of files.
  # Params:
  # +filelist+:: iterator or string that specifies the file (or files) to be hashed and returns the result in a ruby hash (ruby, your terminology sucks).
  class HashFile
    def self.genhash(filelist)
      hashes = {}
      if filelist.respond_to?('each')
        filelist.each do |file|
          filedata = File.read(file)
          # hmac = OpenSSL::HMAC.new(filedata, OpenSSL::Digest::SHA256.new)
          sha256 = Digest::SHA256.new
          puts Mood.happy("Calculating hash for #{file}")
          sha256 << filedata
          hashes[file] = sha256.hexdigest
        end
      else
        filedata = File.read(filelist)
        sha256 = Digest::SHA256.new
        puts Mood.happy("Calculating hash for #{file}")
        sha256 << filedata
        hashes[file] = sha256.hexdigest
      end
      hashes
    end
  end
  # Calculates the difference between dates from specified timestamp to now.
  # Params:
  # +timestamp+:: A timestamp that is either a Time object or a number of seconds from unix epoch.
  class DateDiff
    def self.getdiff(timestamp)
      now = Date.today
      if timestamp.is_a?(Time)
        than = timestamp.to_date
      else
        than = Time.at(timestamp).to_date
      end
      diff = now - than
      return diff.to_i if diff.respond_to?(:to_i)
      diff
    end
  end
  # Checks if the current user's user id is equal to the specified "privileged" user.
  # Params:
  # +user+:: The user that is indicated to have sufficient privileges for the task.
  class IsPrivileged
    def self.check(user = 'root')
      currentuser = Etc.getpwuid
      privuser = nil
      value = false
      if user.respond_to?(:to_s)
        privuser = Etc.getpwnam(user)
      elsif user.respond_to?(:to_i)
        privuser = Etc.getpwuid(user.to_i)
      end
      value = true if currentuser.uid == privuser.uid
      value
    end
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
        sorted = unsorted.sort
      end
      sorted
    end
  end
end
