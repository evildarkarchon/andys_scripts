# frozen_string_literal: true

require 'rom'

module VideoInfo
  module Database
    class Videoinfo < ROM::Relation[:sql]
      schema do
        attribute :id, Types::Int
        attribute :filename, Types::String
        attribute :duration, Types::String
        attribute :duration_raw, Types::Float
        attribute :container, Types::String, null: false
        attribute :bitrate_total, Types::String
        attribute :width, Types::Int
        attribute :height, Types::Int
        attribute :frame_rate, Types::Float
        attribute :bitrate_0, Types::String
        attribute :bitrate_0_raw, Types::Int
        attribute :type_0, Types::String
        attribute :codec_0, Types::String
        attribute :bitrate_1, Types::String
        attribute :bitrate_1_raw, Types::Int
        attribute :type_1, Types::String
        attribute :codec_1, Types::String
        attribute :filehash, Types::String
        primary_key :id
      end
    end
    class Videojson < ROM::Relation[:sql]
      schema do
        attribute :id, Types::Int
        attribute :filename, Types::String
        attribute :jsondata, Types::String
        primary_key :id
      end
    end
  end
end
