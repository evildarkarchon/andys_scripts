require 'data_mapper'

module VideoInfo
  module Database
    class Videoinfo
      include DataMapper::Resource

      storage_names[:default] = 'videoinfo'

      property :id, Serial
      property :filename, Text, lazy: false, key: true, unique: true
      property :duration, String
      property :duration_raw, Float
      property :numstreams, Integer
      property :container, Text, lazy: false
      property :bitrate_total, String
      property :width, Integer
      property :height, Integer
      property :frame_rate, Float
      property :bitrate_0, String
      property :bitrate_0_raw, Integer
      property :type_0, String
      property :codec_0, String
      property :bitrate_1, String
      property :bitrate_1_raw, Integer
      property :type_1, String
      property :codec_1, String
      property :filehash, String, length: 64, unique: true, lazy: false
    end

    class Videojson
      include DataMapper::Resource

      storage_names[:default] = 'videojson'

      property :id, Serial
      property :filename, Text, lazy: false, key: true, unique: true
      property :jsondata, Text, lazy: false
    end
  end
end
