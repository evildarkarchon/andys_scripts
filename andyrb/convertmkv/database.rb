# frozen_string_literal: true

require 'data_mapper'
require 'pathname'

require_relative '../videoinfo/database'
require_relative '../videoinfo/genhash'
require_relative '../util/hashfile'
require_relative '../mood'

module ConvertMkv
  class Database
    def initialize(db, filename, verbose: false)
      @verbose = verbose.freeze
      @filename = filename.freeze
      @filepath = Pathname.new(@filename)

      @db = db.is_a?(Pathname) ? db : Pathname.new(db)
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.setup(:default, "sqlite:#{@db.realpath}")
      DataMapper::Logger.new($stdout, :debug) if @verbose
      begin
        VideoInfo::Database::Videoinfo.auto_upgrade!
        VideoInfo::Database::Videojson.auto_upgrade!
      rescue DataObjects::SyntaxError
        VideoInfo::Database::Videoinfo.auto_migrate!
        VideoInfo::Database::Videojson.auto_migrate!
      end

      @vi = VideoInfo::Database::Videoinfo.new
      @gvi = VideoInfo::Database::Data.new
    end

    def save
      jsondata = @gvi.json(@filename, @verbose)
      outhash = Util.hashfile(@filepath.realpath.to_s).freeze
      VideoInfo.genhash(@filename, jsondata, outhash) do |h|
        begin
          puts Mood.happy("Writing metadata for #{File.basename(@filename)}")
          @vi.attributes = h
          @vi.save
        rescue DataMapper::SaveFailureError
          @vi.errors.each { |e| puts e } if @verbose
        end
      end
    end
  end
end
