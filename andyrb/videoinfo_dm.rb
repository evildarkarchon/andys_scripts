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
require_relative 'videoinfo_dm'

module GenerateVideoInfo
  def self.probe(filepath, verbose = false)
    filepath = Pathname.new(filepath) unless filepath.is_a?(Pathname)
    puts Mood.happy("Extracting metadata from #{filepath.basename}") if @verbose
    out = Subprocess.check_output(['ffprobe', '-i', filepath.realpath.to_s, '-hide_banner', '-of', 'json', '-show_streams', '-show_format', '-loglevel', 'quiet']).to_s
    out = JSON.parse(out)
    yield out if block_given?
    out
  end

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
    property :filehash, String, key: true, unique: true, lazy: false
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
      out = nil
      Videojson.storage_names[repo] = 'videojson' if repo
      filepath = Pathname.new(filepath) unless filepath.respond_to?(:exists)
      insert = Videojson.new
      # puts Videojson.count(filename: filepath.basename.to_s)
      if @db.storage_exists?('videojson') && Videojson.count(filename: filepath.basename.to_s) >= 1
        puts Mood.happy("Reading metadata from cache for #{filepath}") if @verbose
        out = Videojson.all(filename: filepath.basename, fields: [:jsondata])
      else
        puts Mood.happy("Extracting metadata from #{filepath.basename}") if @verbose
        out = Subprocess.check_output(['ffprobe', '-i', filepath.realpath.to_s, '-hide_banner', '-of', 'json', '-show_streams', '-show_format', '-loglevel', 'quiet']).to_s
        cache = JSON.parse(out)
        begin
          puts Mood.happy("Caching JSON for #{filepath.basename}") if @verbose
          insert.attributes = { filename: filepath.basename, jsondata: JSON.generate(cache) }
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

  def self.genhash(filename, inputjson, filehash = nil)
    jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson)) if inputjson.is_a? String
    jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson[0][:jsondata])) if inputjson.is_a? DataMapper::Collection
    # jsondata = Util.recursive_symbolize_keys(jsondata)
    filepath = Pathname.new(filename)
    calc = Dentaku::Calculator.new
    outhash = {}
    outhash[:filename] = filepath.basename.to_s
    outhash[:filehash] = filehash[filepath.realpath.to_s] if filehash
    outhash[:container] = jsondata[:format][:format_name]
    outhash[:duration] = Time.at(jsondata[:format][:duration].to_f).utc.strftime('%H:%M:%S')
    outhash[:duration_raw] = jsondata[:format][:duration]
    outhash[:numstreams] = jsondata[:format][:nb_streams]

    outhash[:bitrate_total] = case
    when jsondata[:format][:bit_rate].to_i >= 1_000_000
      Filesize.from(jsondata[:format]['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata[:format].key?('bit_rate')
      when jsondata[:format][:bit_rate].to_i.between?(1000, 999_999)
        Filesize.from(jsondata[:format]['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s'
      when jsondata[:format][:bit_rate].to_i < 1000
        jsondata[:format][:bit_rate].to_s + 'b/s'
      end # rubocop:disable Lint/EndAlignment

    outhash[:bitrate_0_raw] = case
      when jsondata[:streams][0].key?('bit_rate')
        jsondata[:streams][0]['bit_rate']
      when jsondata[:streams][0][:tags].key?(:BPS)
        jsondata[:streams][0][:tags][:BPS]
      end # rubocop:disable Lint/EndAlignment

    outhash[:bitrate_0] = case
    when outhash[:bitrate_0_raw].to_i >= 1_000_00
      Filesize.from(outhash[:bitrate_0_raw].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s'
    when outhash[:bitrate_0_raw].to_i.between?(1000, 999_999)
      Filesize.from(outhash[:bitrate_0_raw].to_s + 'b').to('Kb').round.to_s + 'Kb/s'
    when outhash[:bitrate_0_raw].to_i < 1000
      outhash[:bitrate_0_raw].to_s + 'b/s'
    end # rubocop:disable Lint/EndAlignment

    outhash[:type_0] = jsondata[:streams][0][:codec_type] if jsondata[:streams][0].key?(:codec_type)
    outhash[:codec_0] = jsondata[:streams][0][:codec_name] if jsondata[:streams][0].key?(:codec_name)

    outhash[:bitrate_1_raw] = case
    when jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?('bit_rate')
      jsondata[:streams][1]['bit_rate']
    when jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?(:tags) && jsondata[:streams][1][:tags].key?(:BPS)
      jsondata[:streams][1][:tags][:BPS]
    end # rubocop:disable Lint/EndAlignment

    outhash[:bitrate_1] = case
    when jsondata[:streams].length >= 2 && outhash[:bitrate_1_raw].to_i >= 1_000_000
      Filesize.from(outhash[:bitrate_1_raw].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s'
    when jsondata[:streams].length >= 2 && outhash[:bitrate_1_raw].to_i.between?(1000, 999_999)
      Filesize.from(outhash[:bitrate_1_raw].to_s + 'b').to('Kb').round.to_s + 'Kb/s'
    when jsondata[:streams].length >= 2 && outhash[:bitrate_1_raw].to_i < 1000
      outhash[:bitrate_1_raw].to_s + 'b/s'
    end # rubocop:disable Lint/EndAlignment

    outhash[:type_1] = jsondata[:streams][1][:codec_type] if jsondata[:streams].length >= 2 && jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?(:codec_type)

    outhash[:codec_1] = jsondata[:streams][1][:codec_name] if jsondata[:streams].length >= 2 && jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?(:codec_name)

    outhash[:height] = case
    when jsondata[:streams][0][:height]
      jsondata[:streams][0][:height]
    when jsondata[:streams].length >= 2 && jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?(:height)
      jsondata[:streams][1][:height]
    end # rubocop:disable Lint/EndAlignment

    outhash[:width] = case
    when jsondata[:streams][0].key?(:width)
      jsondata[:streams][0][:width]
    when jsondata[:streams].length >= 2 && jsondata[:streams][1].respond_to?(:key) && jsondata[:streams][1].key?(:width)
      jsondata[:streams][1][:width]
    end # rubocop:disable Lint/EndAlignment

    outhash[:frame_rate] = nil
    begin
      case # Used 4 'when' statements for readability
      when jsondata.respond_to?(:dig) && jsondata.dig(:streams, 0, :avg_frame_rate)
        outhash[:frame_rate] = calc.evaluate(jsondata[:streams][0][:avg_frame_rate]).to_f.round(2)
      when jsondata.respond_to?(:dig) && jsondata.dig(:streams, 1, :avg_frame_rate)
        outhash[:frame_rate] = calc.evaluate(jsondata[:streams][1][:avg_frame_rate]).to_f.round(2)
      when !jsondata.respond_to?(:dig) && !jsondata[:streams][0].key?(:avg_frame_rate) && jsondata[:streams].length >= 2 && jsondata[:streams][1].key?(:avg_frame_rate)
        outhash[:frame_rate] = calc.evaluate(jsondata[:streams][1][:avg_frame_rate]).to_f.round(2)
      when !jsondata.respond_to?(:dig) && jsondata[:streams][0].key?(:avg_frame_rate)
        outhash[:frame_rate] = calc.evaluate(jsondata[:streams][0][:avg_frame_rate]).to_f.round(2)
      end
    rescue ZeroDivisionError
      outhash[:frame_rate] = nil
    end
    yield outhash if block_given?
    outhash
  end

  def self.genfilelist(filelist, testmode = false, sort = true)
    whitelist = Util.block do
      # wl1 = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska']
      wl1 = %w(video/x-flv video/mp4 video/mp2t video/3gpp video/quicktime video/x-msvideo video/x-ms-wmv video/webm video/x-matroska video/3gpp2 audio/x-wav)
      # wl2 = ['video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']
      wl2 = %w(audio/wave video/dvd video/mpeg application/vnd.rn-realmedia-vbr audio/vnd.rn-realaudio audio/x-realaudio)
      wl1.concat(wl2)
      wl1
    end
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
    outlist = Util.block do
      out = Util::SortEntries.sort(outlist) if sort
      out = outlist unless sort
      out
    end
    yield outlist if block_given?
    outlist
  end

  def self.find(directory, verbose = false)
    magic = FileMagic.new
    dirpath = Pathname.new(directory)
    blacklist = /jpg|gif|png|flv|mp4|mkv|webm|vob|ogg|drc|avi|wmv|yuv|rm|rmvb|asf|m4v|mpg|mp2|mpeg|mpe|mpv|3gp|3g2|mxf|roq|nsv|f4v|wav|ra|mka|pdf|odt|docx|webp|swf|cb7|zip|7z|xml|log/i
    initdirectories = Dir.glob("#{directory}/**/*")
    initdirectories.delete_if { |i| Pathname.new(i).extname =~ blacklist && File.file?(i) }
    directories = []
    initdirectories.each do |i|
      puts Mood.happy { "Serching for databases in #{i}" } if verbose
      result = ''
      result = magic.file(i) if FileTest.file?(i)
      dirpath = Pathname.new(i).realpath
      initdirectories.delete(i) unless result.include?('SQLite 3.x')
      next unless result.include?('SQLite 3.x')
      directories << dirpath.dirname.to_s
    end
    directories.uniq!
    yield directories if block_given?
    directories
  end
end
