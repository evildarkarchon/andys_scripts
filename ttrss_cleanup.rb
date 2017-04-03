# frozen_string_literal: true

require 'pathname'

require 'andyrb/util/datediff'
require 'andyrb/mood'

files = Pathname.new('/data/ttrssbackup').find.to_a
files.keep_if { |i| i.extname.to_s.include?('.xz') }
files.freeze

files.each do |file|
  diff = Util.datediff(file.mtime)
  puts(Mood.happy { "Deleting #{file}" }) if diff > 14
  file.delete if diff > 14
end
