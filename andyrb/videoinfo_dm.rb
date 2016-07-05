require 'data_mapper'
require 'json'
require 'pathname'
require 'filesize'
require 'filemagic'
require 'find'
require 'subprocess'
require 'dentaku'

class VideoInfo
  include DataMapper::Resource
  property :id, Serial
  property :filename, Text
  property :path, FilePath
  property :duration, Time
  property :duration_raw, Float
  property :numstream, Integer
  property :container, Text
  property :width, Integer
  property :height, Integer
  property :frame_rate, Float
  property :file_hash, String, length: 64, key: true

  has n, :streams
end

class Stream0
  include DataMapper::Resource
  property :id, Serial
  property :bitrate, String
  property :bitrate_raw, Integer
  property :type, String
  property :codec, String

  belongs_to :videoinfo
end

class Stream1
  include DataMapper::Resource
  property :id, Serial
  property :bitrate, String
  property :bitrate_raw, Integer
  property :type, String
  property :codec, String

  belongs_to :videoinfo
end
