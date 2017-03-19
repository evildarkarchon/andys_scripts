# frozen_string_literal: true
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
        calc.call(file)
      end
    else
      calc.call(filelist)
    end
    yield hashes if block_given?
    hashes
  end
end
