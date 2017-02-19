require 'pathname'
require 'json'
require 'subprocess'
require 'dentaku'
require 'filesize'
require 'filemagic'
require 'find'

require_relative 'util'
require_relative 'mood'

module VidInfo # rubocop:disable Metrics/ModuleLength
  def self.probe(filepath, verbose = false)
    raise 'First argument must be either a string or a pathname' unless filepath.is_a?(String) || filepath.is_a?(Pathname)
    out = nil
    filepath = Pathname.new(filepath) unless filepath.is_a?(Pathname)
    puts Mood.happy("Extracting metadata from #{filepath.basename}") if verbose
    Util::FindApp.which('ffprobe') do |fp|
      raise 'ffprobe not found' unless fp
      raise 'ffprobe found, but is not executable' if fp && !File.executable?(fp)
      cmd = %W(#{fp} -i #{filepath.realpath} -hide_banner -of json -show_streams -show_format -loglevel quiet)
      out = Util::Program.runprogram(cmd, use_sudo = false, sudo_user = nil, parse_output = true).to_s
    end
    out = JSON.parse(out)
    yield out if block_given?
    out
  end

  def self.genhash(filename, inputjson, filehash = nil)
    raise 'You must supply either a json string, or a pre-parsed hash' unless inputjson.is_a?(String) || inputjson.is_a?(Hash) || inputjson.is_a?(DataMapper::Collection)

    jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson)) if inputjson.is_a?(String)
    jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson[0][:jsondata])) if inputjson.is_a?(DataMapper::Collection)
    jsondata = Util.recursive_symbolize_keys(inputjson) if inputjson.is_a?(Hash)

    filepath = Pathname.new(filename)

    calc = Dentaku::Calculator.new

    fs = lambda do |n|
      out =
        case
        when n.to_i >= 1_000_000
          Filesize.from(n.to_s + 'b').to('Mb').round(2).to_s + 'Mb/s'
        when n.to_i.between?(1000, 999_999)
          Filesize.from(n.to_s + 'b').to('Kb').round.to_s + 'Kb/s' if n.to_i.between?(1000, 999_999)
        when n.to_i < 1000
          n.to_s + 'b/s'
        end
      out
    end

    fr = lambda do |s|
      out =
        case
        when jsondata.respond_to?(:dig)
          jsondata.dig(:streams, s, :avg_frame_rate)
        when jsondata[:streams][s] && jsondata[:streams][s].is_a?(Hash) && jsondata[:streams][s].key?(:avg_frame_rate) && !jsondata.respond_to?(:dig)
          true
        end
      out
    end

    frc = lambda do |n|
      begin
        calc.evaluate(n).to_f.round(2)
      rescue ZeroDivisionError
        nil
      end
    end

    brr = lambda do |n|
      dig = jsondata.respond_to?(:dig)
      nh = jsondata[:streams][n].is_a?(Hash)
      out =
        case
        when dig && jsondata.dig(:streams, n, :bit_rate), !dig && nh && jsondata[:streams][n].key?(:bit_rate)
          jsondata[:streams][n][:bit_rate]
        when dig && jsondata.dig(:streams, n, :tags, :BPS), !dig && nh && jsondata[:streams][n][:tags].is_a?(Hash) && jsondata[:streams][n][:tags].key?(:BPS)
          jsondata[:streams][n][:tags][:BPS]
        end
      out
    end

    outhash = {}
    outhash[:filename] = filepath.basename.to_s
    outhash[:filehash] = filehash[filepath.realpath.to_s] if filehash
    outhash[:container] = jsondata[:format][:format_name]
    outhash[:duration] = Time.at(jsondata[:format][:duration].to_f).utc.strftime('%H:%M:%S')
    outhash[:duration_raw] = jsondata[:format][:duration]
    outhash[:numstreams] = jsondata[:format][:nb_streams]
    outhash[:bitrate_total] = fs.call(jsondata[:format][:bit_rate])
    outhash[:bitrate_0_raw] = brr.call(0)
    outhash[:bitrate_0] = fs.call(outhash[:bitrate_0_raw])
    outhash[:type_0] = jsondata[:streams][0][:codec_type] if jsondata[:streams][0].key?(:codec_type)
    outhash[:codec_0] = jsondata[:streams][0][:codec_name] if jsondata[:streams][0].key?(:codec_name)
    outhash[:bitrate_1_raw] = brr.call(1) if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash)

    outhash[:bitrate_1] = fs.call(outhash[:bitrate_1_raw]) if outhash[:bitrate_1_raw]

    outhash[:type_1] = jsondata[:streams][1][:codec_type] if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1].key?(:codec_type)

    outhash[:codec_1] = jsondata[:streams][1][:codec_name] if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1].key?(:codec_name)

    outhash[:height] =
      case
      when jsondata[:streams][0][:height]
        jsondata[:streams][0][:height]
      when jsondata[:streams].length >= 2 && jsondata[:streams][1].respond_to?(:key?) && jsondata[:streams][1].key?(:height)
        jsondata[:streams][1][:height]
      end

    outhash[:width] =
      case
      when jsondata[:streams][0].key?(:width)
        jsondata[:streams][0][:width]
      when jsondata[:streams].respond_to?(:length) && jsondata[:streams].length >= 2 && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1].key?(:width)
        jsondata[:streams][1][:width]
      end

    outhash[:frame_rate] =
      case
      when fr.call(0)
        frc.call(jsondata[:streams][0][:avg_frame_rate])
      when fr.call(1)
        frc.call(jsondata[:streams][1][:avg_frame_rate])
      end
    yield outhash if block_given?
    outhash
  end

  def self.genfilelist(filelist, testmode = false, sort = true)
    whitelist = %w(video/x-flv video/mp4 video/mp2t video/3gpp video/quicktime video/x-msvideo video/x-ms-wmv video/webm video/x-matroska video/3gpp2 audio/x-wav)
    whitelist += %w(audio/wave video/dvd video/mpeg application/vnd.rn-realmedia-vbr audio/vnd.rn-realaudio audio/x-realaudio)
    magic = FileMagic.new(:mime_type)
    filelist = Util::SortEntries.sort(filelist) if sort
    puts 'Files to be examined:' if testmode
    outlist = []
    filelist.each do |entry|
      if testmode
        puts magic.flags
        puts magic.file(entry)
      end
      outlist << entry if whitelist.include?(magic.file(entry)) && !testmode
      puts Mood.happy { entry } if whitelist.include?(magic.file(entry)) && testmode
    end
    magic.close
    outlist = Util::SortEntries.sort(outlist) if sort
    yield outlist if block_given?
    outlist
  end

  def self.find(directory, verbose = false)
    magic = FileMagic.new
    dirpath = Pathname.new(directory)
    blacklist = /jpg|gif|png|flv|mp4|mkv|webm|vob|ogg|drc|avi|wmv|yuv|rm|rmvb|asf|m4v|mpg|mp2|mpeg|mpe|mpv|3gp|3g2|mxf|roq|nsv|f4v|wav|ra|mka|pdf|odt|docx|webp|swf|cb7|zip|7z|xml|log/i
    initdirectories = dirpath.find.to_a
    initdirectories.keep_if(&:file?)
    initdirectories.delete_if { |i| i.extname =~ blacklist }
    initdirectories.keep_if do |i|
      result = magic.file(i.to_s)
      result.include?('SQLite 3.x')
    end
    directories = []
    initdirectories.each do |i|
      puts Mood.happy { "Adding #{i.dirname} to list" } if verbose
      directories << i.dirname
    end
    directories.uniq!
    yield directories if block_given?
    directories
  end
end
