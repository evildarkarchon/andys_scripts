# frozen_string_literal: true

require 'data_mapper'
require 'pathname'
require 'fileutils'

require_relative '../videoinfo/database'
require_relative '../mood'

module ConvertMkv
  class Backup
    def initialize(source, dest, db: nil)
      if db # rubocop:disable Style/GuardClause
        @db = db.is_a?(Pathname) ? db : Pathname.new(db)
        DataMapper::Model.raise_on_save_failure = true
        DataMapper.setup(:default, "sqlite:#{@db.realpath}")
        @source = source.to_s
        @dest = dest.to_s
      end
    end

    def exec
      puts Mood.happy("Moving #{@source} to #{@dest}")
      FileUtils.mv(@source, @dest) unless Args.debug

      if @db # rubocop:disable Style/GuardClause
        vientry = VideoInfo::Database::Videoinfo.all(filename: @source)
        vientry.destroy
      end
    end
  end
end
