# frozen_string_literal: true

require 'data_mapper'

require_relative '../videoinfo/database'

module ABSConvert
  class Metadata
    attr_reader :bitrates, :frame_rate
    def initialize(filename, db, verbose: false, videobitrate: nil, audiobitrate: nil, framerate: nil)
      raise TypeError, 'db must be a Pathname' unless db.is_a?(Pathname)
      @verbose = verbose
      DataMapper.setup(:default, "sqlite:#{db.realpath}")
      DataMapper::Logger.new($stdout, :debug) if @verbose
      path = File.basename(filename).freeze
      @query = VideoInfo::Database::Videoinfo.all(filename: path, fields: %i[bitrate_0_raw type_0 bitrate_1_raw type_1 frame_rate])
      @frame_rate = framerate
      @bitrates = {}
      @bitrates[:video] = nil
      @bitrates[:audio] = nil
      @videobitrate = videobitrate
      @audiobitrate = audiobitrate
    end

    def bitrate!
      @bitrates[:video] =
        case
        when @videobitrate
          @videobitrate
        when @query[0][:type_0] == 'video'
          @query[0][:bitrate_0_raw]
        when @query[0][:type_1] == 'video'
          @query[0][:bitrate_1_raw]
        end

      @bitrates[:audio] =
        case
        when @audiobitrate
          @audiobitrate
        when @query[0][:type_0] == 'audio'
          @query[0][:bitrate_0_raw]
        when @query[0][:type_1] == 'audio'
          @query[0][:bitrate_1_raw]
        end
      @bitrates.freeze
    end

    def framerate!
      @frame_rate = @query[0][:frame_rate] unless @frame_rate
      @frame_rate.freeze
    end
  end
end
