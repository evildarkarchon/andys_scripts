# frozen_string_literal: true

require 'nokogiri'
require 'pathname'
require 'addressable'
require 'htmlentities'
require 'xspf'
require 'filemagic'
require 'fileutils'

begin
  rv = Gem::Version.new(RUBY_VERSION.to_s.freeze)
  rvm = Gem::Version.new('2.3.0')
  require 'ruby_dig' if rv < rvm
rescue LoadError => e
  raise e if rv < rvm
end

require_relative '../videoinfo/probe'

module YTDL
  class Playlist
    def initialize(filelist, outname, videodir, rootdir = '/data/Videos', resetplaylist: false, pretend: false, noblacklist: false)
      @filelist = filelist.dup
      @rootdir = rootdir
      @rootpath = Pathname.new(rootdir)
      @outname = outname.to_s
      @outpath = Pathname.new(@outname)
      @outdir = @outpath.dirname
      @resetplaylist = resetplaylist
      @pretend = pretend
      @noblacklist = noblacklist
      @blacklistrun = false
      @videodir = videodir
      @videopath = Pathname.new(videodir)
    end

    def blacklist
      return if @blacklistrun
      filenames = @filelist.dup
      filenames.map! { |i| "#{i}\n" }
      n = @videodir + '.noplaylist'
      o = n.exist? ? File.readlines(n.to_s) : nil
      begin
        n.open('a') do |x|
          filenames.each do |i|
            puts(Mood.happy { "Writing #{File.basename(i.to_s.strip)} to #{n}" }) unless [@pretend, @noblacklist, o && o.include?(i)].any?
            x.write(i) unless [@pretend, @noblacklist, o && o.include?(i)].any?
          end
        end
      rescue Interrupt => e
        raise e
      else
        @blacklistrun = true
      end
      puts(Mood.neutral { 'File names to put on the playlist blacklist:' }) if [@pretend, !@noblacklist].all?
      filenames.each { |i| puts i } if [@pretend, !@noblacklist].all?
    end

    private def genplaylisthash(filename, driveletter = 'z')
      jsondata = VideoInfo.probe(filename)
      filepath = Pathname.new(filename)
      coder = HTMLEntities.new

      out = { location: Addressable::URI.convert_path("#{driveletter}:/#{filepath.realpath.relative_path_from(@rootpath)}").to_s.gsub("'", "\\\\'") }

      if jsondata.dig(:format, :tags)
        out[:title] = jsondata[:format][:tags][:title].gsub("'", "\\\\'") if jsondata.dig(:format, :tags, :title)
        # out[:annotation] = coder.escape(jsondata[:format][:tags][:DESCRIPTION]).gsub("'", "\\\\'") if jsondata.dig(:format, :tags, :DESCRIPTION)
        out[:annotation] = coder.encode(jsondata[:format][:tags][:DESCRIPTION]) if jsondata.dig(:format, :tags, :DESCRIPTION)
        out[:creator] = jsondata[:format][:tags][:ARTIST].gsub("'", "\\\\'") if jsondata.dig(:format, :tags, :ARTIST)
        out[:duration] = jsondata[:format][:duration].to_f.round.to_s if jsondata.dig(:format, :duration)
      end
      out
    end

    def genplfilelist!(driveletter = 'z')
      whitelist = %w[video/x-flv video/mp4 audio/x-m4a video/mp2t video/3gpp video/quicktime video/x-msvideo video/x-ms-wmv video/3gpp2 audio/x-wav]
      whitelist += %w[audio/wave video/dvd video/mpeg application/vnd.rn-realmedia-vbr audio/vnd.rn-realaudio audio/x-realaudio]
      whitelist += %w[video/webm video/x-matroska audio/x-matroska]
      whitelist.freeze
      magic = FileMagic.new(:mime_type)

      existing = []
      blacklist = @videopath.join('.noplaylist').readlines if @videopath.join('.noplaylist').file?
      puts Mood.neutral('Blacklist Content:') if @pretend
      blacklist.map!(&:strip) if [@pretend, blacklist.respond_to?(:map)].all?
      puts blacklist.inspect if @pretend

      if @outpath.exist? && !@resetplaylist
        o = File.open(@outname)
        begin
          xspf = XSPF.new(o)
          playlist = xspf.playlist
          tracklist = playlist.tracklist
          existing = tracklist.tracks
          existing.map!(&:location) if [existing.respond_to?(:map!), existing.respond_to?(:empty?) && !existing.empty?].all?
        rescue NoMethodError
          nil
        end
        o.close
      end

      @filelist.keep_if { |i| File.dirname(i.to_s) == @videodir.to_s }

      uris = existing.map { |x| Addressable::URI.parse(x).to_s } if @pretend && !existing.empty?
      puts(Mood.neutral { 'Existing URIs:' }) if [@pretend, uris].all?
      puts uris.inspect if [@pretend, uris].all?

      unless [existing.respond_to?(:empty?) && existing.empty?, @resetplaylist, @pretend].any?
        @filelist.delete_if do |i|
          url = Addressable::URI.convert_path("#{driveletter[0]}:/#{i.relative_path_from(@rootpath)}").to_s
          uris = existing.map { |x| Addressable::URI.parse(x).to_s }
          uris.any? { |y| url.include? y }
        end
      end

      unless [!defined?(blacklist), blacklist && blacklist.respond_to?(:empty?) && blacklist.empty?, @resetplaylist, @noblacklist].any?
        @filelist.delete_if { |i| blacklist.to_s.include?(i.to_s) }
      end

      @filelist.keep_if { |file| whitelist.include?(magic.file(file.to_s)) }

      puts(Mood.neutral { 'No files to add to the playlist' }) if @filelist.empty?
      puts(Mood.neutral { 'Playlist file list:' }) if @pretend
      puts @filelist.inspect if @pretend
      puts(Mood.neutral { 'Playlist output path:' }) if @pretend
      puts @outpath.inspect if @pretend
    end

    def genplaylist
      tracklist = nil
      playlist = nil
      xspf = nil

      tracklist = XSPF::Tracklist.new unless tracklist.instance_of?(XSPF::Tracklist)

      if [@outpath.respond_to?(:exist?) && @outpath.exist?, !@resetplaylist].all?
        o = File.new(@outname.to_s)
        begin
          xspf = XSPF.new(o)
          playlist = xspf.playlist
          tracklist = playlist.tracklist
        rescue NoMethodError
          nil
        end
        o.close
      end

      @filelist.each do |file|
        puts(Mood.happy { "Adding #{File.basename(file.to_s)} to playlist" })
        track = XSPF::Track.new(genplaylisthash(file))
        tracklist << track
      end

      playlist = XSPF::Playlist.new(tracklist: tracklist) unless playlist.instance_of?(XSPF::Playlist)
      xspf = XSPF.new(playlist: playlist) unless xspf.instance_of?(XSPF)

      puts(Mood.happy { "Creating Directory #{@outdir}" }) unless @pretend || @outdir.exist?
      @outdir.mkpath unless @pretend || @outdir.exist?
      ng = Nokogiri.XML(xspf.to_xml)

      unless @pretend
        FileUtils.touch(@outname) unless File.exist?(@outname)
        File.open(@outname, 'w') do |f|
          puts(Mood.happy { "Writing playlist to #{@outname}" })
          f.write(ng.to_s)
        end
      end
      puts(Mood.neutral { 'Playlist XML Content:' }) if @pretend
      puts ng if @pretend
    end

    def inspect
      "YTDL::Playlist<@filelist = #{@filelist}, @rootdir = #{@rootdir}, @outname = #{@outname}, @outdir = #{@outdir}, @resetplaylist = #{@resetplaylist}, @pretend = #{@pretend}, @noblacklist = #{@noblacklist}, @videodir = #{@videodir}>"
    end
  end
end
