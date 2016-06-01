require 'fileutils'
require 'pathname'
require 'subprocess'
require 'mkmf'

require_relative 'videoinfo'
require_relative 'mood'
require_relative 'util'

module ABSConvert
  class Util
=begin
    def initialize(database)
      @vi = VideoInfo::Database.new(Pathname.new(database).realpath.to_s)
    end
=end
    def self.auto_bitrates(filename, database)
      vi = VideoInfo::Database.new(Pathname.new(database).realpath.to_s)
      dbinfo = vi.readhash('select bitrate_0_raw, bitrate_1_raw, type_0, type_1 from videoinfo where filename=?', filename)
      bitrates = {}

      bitrates['video'] = dbinfo['bitrate_0_raw'] if dbinfo['type_0'] == 'video'
      bitrates['video'] = dbinfo['bitrate_1_raw'] if dbinfo['type_1'] == 'video'

      bitrates['audio'] = dbinfo['bitrate_0_raw'] if dbinfo['type_0'] == 'audio'
      bitrates['audio'] = dbinfo['bitrate_1_raw'] if dbinfo['type_1'] == 'audio'

      bitrates
    end
  end

  class Convert
    def initialize(videocodec = nil, videobitrate = nil, audiocodec = nil, audiobitrate = nil, videocodecopts = nil, audiocodecopts = nil, audiofilteropts = nil, container = nil, framerate = nil, passes = 2) # rubocop:disable Metrics/ParameterLists
      
    end
  end
end
