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
    def initialize(videocodec = nil, videobitrate = nil, videocodecopts = nil, audiocodec = nil, audiobitrate = nil, audiocodecopts = nil, audiofilteropts = nil, container = nil, framerate = nil) # rubocop:disable Metrics/ParameterLists
      @videocodec = videocodec
      @videobitrate = videobitrate
      @videocodecopts = videocodecopts
      @audiocodec = audiocodec
      @audiobitrate = audiobitrate
      @audiocodecopts = audiocodecopts
      @audiofilteropts = audiofilteropts
      @container = container
      @framerate = framerate

      @nocodec = [nil, 'none', 'copy']

      @mkvpropedit = find_executable('mkvpropedit')
      @ffmpeg = find_executable('ffmpeg')

      raise Mood.sad('Unable to find ffmpeg, exiting.') unless @ffmpeg
    end

    def convertpass1
      # insert code here
    end

    def convertpass2
      # insert code here
    end

    def convert1pass
      # insert code here
    end
  end
end
