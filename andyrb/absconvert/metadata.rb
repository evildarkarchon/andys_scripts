# frozen_string_literal: true

require 'data_mapper'

require_relative '../videoinfo/database'

module ABSConvert
  class Metadata
    attr_reader :bitrates, :frame_rate
    def initialize(filename, db, verbose: false, videobitrate: nil, audiobitrate: nil, framerate: nil, novideo: false)
      raise TypeError, 'db must be a Pathname or convertable to one.' unless db.is_a?(Pathname) || db.is_a?(String)
      db = Pathname.new(db) unless db.is_a?(Pathname)
      @verbose = verbose
      DataMapper.setup(:default, "sqlite:#{db.realpath}")
      DataMapper::Logger.new($stdout, :debug) if @verbose
      path = File.basename(filename).freeze
      @query = VideoInfo::Database::Videoinfo.all(filename: path, fields: %i[bitrate_0_raw type_0 bitrate_1_raw type_1 frame_rate])
      @metadata = {}
      @metadata[:frame_rate] =
        case
        when novideo
          nil
        when framerate
          framerate
        when @query[0][:frame_rate]
          @query[0][:frame_rate]
        end

      @metadata[:bitrates] = {}

      @metadata[:bitrates][:video] =
        case
        when videobitrate
          videobitrate
        when @query[0][:type_0] == 'video'
          @query[0][:bitrate_0_raw]
        when @query[0][:type_1] == 'video'
          @query[0][:bitrate_1_raw]
        end

      @metadata[:bitrates][:audio] =
        case
        when audiobitrate
          audiobitrate
        when @query[0][:type_0] == 'audio'
          @query[0][:bitrate_0_raw]
        when @query[0][:type_1] == 'audio'
          @query[0][:bitrate_1_raw]
        end
    end

    def inspect
      "ABSConvert::Metadata<@verbose = #{@verbose}, @metadata = #{@metadata}, @query = #{@query}, @videobitrate = #{@videobitrate}, @audiobitrate = #{@audiobitrate}>"
    end

    def to_h
      hash = @metadata.dup
      hash
    end

    def [](key)
      hash = @metadata.dup
      hash[key]
    end
  end
end
