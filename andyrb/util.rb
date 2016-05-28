require_relative 'mood'
require 'openssl'
require 'pathname'
require 'date'
# rubocop disable:Metrics/MethodLength
class Util
  def self.hashfile(filelist)
    if filelist.is_a?(Array)
      filelist.each do |file|
        filedata = File.read(file)
        hmac = OpenSSL::HMAC.new(filedata, OpenSSL::Digest::SHA256.new)
        return hmac.hexdigest
      end
    else
      filedata = File.read(filelist)
      hmac = OpenSSL::HMAC.new(filedata, OpenSSL::Digest::SHA256.new)
      return hmac.hexdigest
    end
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
