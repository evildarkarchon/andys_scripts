require_relative 'mood'
require 'digest'
require 'pathname'
require 'date'
# rubocop disable:Metrics/MethodLength
class Util
  def self.hashfile(filelist)
    hashes = {}
    if filelist.respond_to?('each')
      filelist.each do |file|
        filedata = File.read(file)
        # hmac = OpenSSL::HMAC.new(filedata, OpenSSL::Digest::SHA256.new)
        sha256 = Digest::SHA256.new
        sha256 << filedata
        hashes[file] = sha256.hexdigest
      end
    else
      filedata = File.read(filelist)
      sha256 = Digest::SHA256.new
      sha256 << filedata
      hashes[file] = sha256.hexdigest
    end
    hashes
  end

  def self.datediff(timestamp)
    now = Date.today
    if timestamp.is_a?(Time)
      than = timestamp.to_date
    else
      than = Time.at(timestamp).to_date
    end
    diff = now - than
    return diff.to_i if diff.respond_to?(:to_i)
  end
end
