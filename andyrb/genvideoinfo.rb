require 'data_mapper'
require 'json'
require 'pathname'
require 'filesize'
require 'filemagic'
require 'find'
require 'subprocess'
require 'dentaku'
# rubocop:disable Metrics/ModuleLength, Style/CaseIndentation, Lint/UnneededDisable, Style/ConstantName
require_relative 'mood'
require_relative 'util'
require_relative 'vidinfo'

module GenerateVideoInfo
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

  class Data
    def initialize(dbpath, verbose = false)
      @dbpath = Pathname.new(dbpath)
      @verbose = verbose
      DataMapper.setup(:default, "sqlite:#{@dbpath.realpath}")
      DataMapper::Logger.new($stdout, :debug) if @verbose
      @db = DataMapper.repository(:default).adapter
      @vi = Videoinfo.new
      @vj = Videojson.new
      DataMapper.finalize
      DataMapper::Model.raise_on_save_failure = true
    end

    def existing
      out = nil
      out = Videoinfo.all(fields: [:filename, :filehash]).to_a if Videoinfo.count >= 1
      # print out.inspect
      out
    end

    def json(filepath, repo = nil)
      raise 'First argument must be either a string or a pathname' unless filepath.is_a?(String) || filepath.is_a?(Pathname)
      out = nil
      Videojson.storage_names[repo] = 'videojson' if repo
      filepath = Pathname.new(filepath) unless filepath.is_a?(Pathname)
      insert = Videojson.new
      # puts Videojson.count(filename: filepath.basename.to_s)
      if @db.storage_exists?('videojson') && Videojson.count(filename: filepath.basename.to_s) >= 1
        puts Mood.happy("Reading metadata from cache for #{filepath}") if @verbose
        out = Videojson.all(filename: filepath.basename, fields: [:jsondata])
      else
        out = VidInfo.probe(filepath.realpath.to_s, verbose: @verbose)
        begin
          puts Mood.happy("Caching JSON for #{filepath.basename}") if @verbose
          insert.attributes = { filename: filepath.basename, jsondata: JSON.generate(out) }
          # print @vi.attributes
          insert.save
          # print "\n"
        rescue DataMapper::SaveFailureError
          insert.errors.each { |e| puts e } if @verbose
          raise "Save failure error raised for #{filepath.basename}" if @verbose
        end
      end
      out
    end
  end
end
