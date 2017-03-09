require 'openssl'

require_relative '../mood'

module Util
  def self.hashfile(filelist)
    hashes = {}
    sha256 = OpenSSL::Digest.new('sha256')
    calc = lambda do |i|
      sha256.reset
      filedata = File.read(i)
      puts Mood.happy { "Calculating hash for #{i}" }
      sha256 << filedata
      hashes[i] = sha256.hexdigest
    end
    if filelist.respond_to?(:each)
      filelist.each do |file|
        # filedata = File.read(file)
        # sha256 = Digest::SHA256.new
        # sha256 = OpenSSL::Digest.new('sha256')
        # puts Mood.happy { "Calculating hash for #{file}" }
        # sha256 << filedata
        # hashes[file] = sha256.hexdigest
        calc.call(file)
      end
    else
      # filedata = File.read(filelist)
      # sha256 = Digest::SHA256.new
      # sha256 = OpenSSL::Digest.new('sha256')
      # puts Mood.happy { "Calculating hash for #{filelist}" }
      # sha256 << filedata
      # hashes[filelist] = sha256.hexdigest
      calc.call(filelist)
    end
    yield hashes if block_given?
    hashes
  end
end
