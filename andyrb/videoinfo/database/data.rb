# frozen_string_literal: true
require 'data_mapper'
require 'pathname'

require_relative '../probe'
require_relative 'schema'

module VideoInfo
  module Database
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
        # out = nil
        # out = Videoinfo.all(fields: [:filename, :filehash]) if Videoinfo.count >= 1
        # print out.inspect
        out = Videoinfo.count >= 1 ? Videoinfo.all(fields: [:filename, :filehash]) : nil
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
          out = out[0][:jsondata]
        else
          out = VideoInfo.probe(filepath.realpath.to_s, verbose: @verbose)
          begin
            puts Mood.happy("Caching JSON for #{filepath.basename}") if @verbose
            insert.attributes = { filename: filepath.basename, jsondata: out.to_json }
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
end
