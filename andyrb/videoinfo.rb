require 'sqlite3'
require 'json'
require 'pathname'
require 'filesize'
require 'filemagic'
require 'find'
require 'subprocess'
require 'dentaku'
# rubocop:disable Style/MultilineOperationIndentation, Performance/StringReplacement
# insert documentation here
require_relative 'mood'
module VideoInfo
  CreateStatement = 'CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_0_raw integer, type_0 text, codec_0 text, bitrate_1 text, bitrate_1_raw integer, type_1 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'.freeze
  CreateStatementJSON = 'CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'.freeze

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

  class Database
    def initialize(dbpath = './videoinfo.sqlite')
      @dbpath = Pathname.new(dbpath)
      @dbpath = @dbpath.realpath if @dbpath.exist?
      @db = SQLite3::Database.new(@dbpath.to_s)
      @db.type_translation = true
      @db.auto_vacuum = true unless @db.auto_vacuum
      @db.cache_size = -2000 unless @db.cache_size <= -2000
      @db.execute 'vacuum'
    end

    def write(query, *values)
      dbvalues = values.to_a if values.respond_to?(:to_a)
      @db.execute(query, dbvalues)
    end

    def writenp(query, inputhash)
      input = inputhash.to_h if inputhash.respond_to?(:to_h)
      @db.execute(query, input)
    end

    def read(query, *values)
      inputvalues = values.to_a if values.respond_to?(:to_a)
      output = @db.execute(query, inputvalues)
      output = nil if output.empty?
      output = output[0] if output.respond_to?(:length) && output.length == 1 && output.respond_to?(:index)
      output = output[0] if output.respond_to?(:length) && output.length == 1 && output.respond_to?(:index)
      yield output if block_given?
      output
    end

    def readhash(query, *values)
      @db.results_as_hash = true
      inputvalues = values.to_a if values.respond_to?(:to_a)
      output = @db.execute(query, inputvalues)
      output = nil if output.empty?
      @db.results_as_hash = false
      output = output[0] if output.is_a?(Array) && output.length == 1
      yield output if block_given?
      output
    end

    def query(input, *values)
      var = @db.execute(input, values)
      yield var if block_given?
      var
    end

    def querynp(input, **values)
      var = @db.execute(input, values)
      yield var if block_given?
      var
    end

    def queryblock
      yield @db
    end

    def vacuum
      @db.execute 'vacuum'
    end

    def createvitable
      puts Mood.happy { 'Creating videoinfo table.' }
      @db.execute CreateStatement
      @db.execute 'vacuum'
    end

    def createjsontable
      puts Mood.happy { 'Creating JSON cache table.' }
      @db.execute CreateStatementJSON
      @db.execute 'vacuum'
    end

    def resetvideoinfo
      puts Mood.happy { "Regenerating Videoinfo Table for #{@dbpath.realpath}" }
      @db.execute 'drop table if exists videoinfo'
      @db.execute CreateStatement
      @db.execute 'vacuum'
    end

    def resetjson
      puts Mood.happy { "Purging JSON cache from #{@dbpath.realpath}" }
      @db.execute 'drop table if exists videojson'
      @db.execute CreateStatementJSON
      @db.execute 'vacuum'
    end

    def deleteentry(criteria, value)
      puts Mood.happy { "Deleting #{value} from videoinfo" }
      @db.execute 'delete from videoinfo where ? = ?', [criteria, value]
    end

    def deletefileentry(value)
      puts Mood.happy { "Deleting #{value} from videoinfo" }
      @db.execute 'delete from videoinfo where filename = ?', [value]
    end
  end

  class Generate
    def initialize(dbpath = './videoinfo.sqlite')
      @dbpath = Pathname.new(dbpath)
      @rtjcount = 0
      @rtvcount = 0
      @vi = Database.new(@dbpath.realpath.to_s)
      # @db = SQLite3::Database.new(@dbpath.to_s)
      @ffprobe = Util::FindApp.which('ffprobe')
      raise 'ffprobe not found.' unless @ffprobe
    end

    def write(inputhash, inputjson, verbose = false, filename = nil)
      columns = inputhash.keys.to_a.join(', ').gsub(':', '').gsub('[', '').gsub(']', '')
      jsondata = JSON.parse(inputjson)
      placeholders = ':' + inputhash.keys.join(', :')
      viquery = "insert into videoinfo (#{columns}) values (#{placeholders})"

      if verbose == true
        puts viquery
        puts inputhash
      end

      begin
        puts Mood.happy { name = "Writing metadata for #{jsondata['format']['filename']}" unless filename; name = "Writing metadata for #{Pathname.new(filename).realpath}" if filename; name } # rubocop:disable Style/Semicolon
        @vi.write(viquery, inputhash)
      rescue SQLite3::SQLException => e
        @rtvcount += 1
        puts Mood.neutral { 'VideoInfo table not found, creating and retrying.' }
        @vi.createvitable
        puts Mood.neutral { "Try \##{@rtvcount}" } if verbose
        retry if @rtvcount <= 5
      end

      begin
        cached = @vi.read('select filename from videojson where filename = ?', inputhash['filename'])
        puts Mood.happy { "Caching JSON for #{inputhash['filename']}" } if cached.nil? || cached.empty?
        @vi.write('insert into videojson (filename, jsondata) values (?, ?)', inputhash['filename'], inputjson) if cached.nil? || cached.empty?
      rescue SQLite3::SQLException => e
        puts e.message
        @vi.createjsontable
        @rtjcount += 1
        retry if @rtjcount <= 5
      end
    end

    def existing
      existing = nil
      begin
        existing = @vi.readhash('select filename, hash from videoinfo')
        existing = nil if existing.nil? || existing.empty?
      rescue SQLite3::SQLException
        existing = nil
      end
      existing
    end

    def self.filelist(filelist, testmode = false, sort = true)
      whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']
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

    def json(filename, verbose = false)
      output = nil
      testresult = nil
      file = Pathname.new(filename).realpath
      begin
        testresult = @vi.read('select jsondata from videojson where filename = ?', File.basename(filename)).to_s
      rescue SQLite3::SQLException
        @vi.createjsontable
        @rtjcount += 1
        puts Mood.neutral "Try \##{@rtjcount}" if verbose
        retry if @rtjcount <= 5
      else
        output = testresult unless testresult.nil? || testresult.empty?
        out = Mood.happy do
          cout = "Reading metadata from cache for #{file}" unless testresult.nil? || testresult.empty?
          cout = "Extracting metadata from #{file}" if testresult.nil? || testresult.empty?
          cout
        end
        puts out # See what i did there, lol
        output = Subprocess.check_output(['ffprobe', '-i', filename, '-hide_banner', '-of', 'json', '-show_streams', '-show_format', '-loglevel', 'quiet']).to_s if testresult.nil? || testresult.empty?
        puts output if verbose
      end
      output
    end

    def self.hash(filename, inputjson, filehash)
      jsondata = JSON.parse(inputjson)
      filepath = Pathname.new(filename)
      calc = Dentaku::Calculator.new
      outhash = {}
      # print "#{filehash}\n"

      outhash['filename'] = filepath.basename.to_s
      outhash['hash'] = filehash[filename]
      outhash['container'] = jsondata['format']['format_name']
      outhash['duration'] = Time.at(jsondata['format']['duration'].to_f).utc.strftime('%H:%M:%S')
      outhash['duration_raw'] = jsondata['format']['duration']
      outhash['streams'] = jsondata['format']['nb_streams']
      outhash['bitrate_total'] = Util.block do
        out = Filesize.from(jsondata['format']['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i >= 1_000_000

        out = Filesize.from(jsondata['format']['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i.between?(1000, 999_999)

        out = jsondata['format']['bit_rate'].to_s + 'b/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i < 1000

        out
      end

      outhash['bitrate_0'] = Util.block do
        out = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'][0].key?('bit_rate') && \
        jsondata['streams'][0]['bit_rate'].to_i >= 1_000_000

        out = Filesize.from(jsondata['streams'][0]['tags']['BPS'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS') && \
        jsondata['streams'][0]['tags']['BPS'].to_i >= 1_000_000

        out = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'].to_i.between?(1000, 999_999)

        out = jsondata['streams'][0]['bit_rate'].to_s + 'b/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'].to_i < 1000

        out = Filesize.from(jsondata['streams'][0]['tags']['BPS'].to_s + 'b').to('Kb').to_s + 'Kb/s' if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags']['BPS'].to_i.between?(1000, 999_999)

        out = jsondata['streams'][0]['tags']['BPS'].to_s + 'b/s' if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags']['BPS'].to_i < 1000

        out
      end

      outhash['bitrate_0_raw'] = Util.block do
        out = jsondata['streams'][0]['bit_rate'] if jsondata['streams'][0].key?('bit_rate')
        out = jsondata['streams'][0]['tags']['BPS'] if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS')
        out
      end

      outhash['type_0'] = jsondata['streams'][0]['codec_type'] if jsondata['streams'][0].key?('codec_type')
      outhash['codec_0'] = jsondata['streams'][0]['codec_name'] if jsondata['streams'][0].key?('codec_name')

      outhash['bitrate_1'] = Util.block do
        out = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i >= 1_000_000

        out = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i.between?(1000, 999_999)
        jsondata['streams'][1]['bit_rate'].to_s + 'b/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i < 1000

        out = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('tags') && \
        jsondata['streams'][1]['tags'].key?('BPS') && jsondata['streams'][1]['tags']['BPS'].to_i >= 1_000_000

        out = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'].length >= 2 && \
        jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS') && jsondata['streams'][1]['tags']['BPS'].to_i.between?(1000, 999_999)

        out = jsondata['streams'][1]['tags']['BPS'].to_s + 'b/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('tags') && \
        jsondata['streams'][1]['tags'].key?('BPS') && jsondata['streams'][1]['tags']['BPS'].to_i < 1000

        out
      end

      outhash['bitrate_1_raw'] = Util.block do
        out = jsondata['streams'][1]['bit_rate'] if jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('bit_rate')
        out = jsondata['streams'][1]['tags']['BPS'] if jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS')
        out
      end

      outhash['type_1'] = jsondata['streams'][1]['codec_type'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('codec_type')
      outhash['codec_1'] = jsondata['streams'][1]['codec_name'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('codec_name')

      outhash['height'] = Util.block do
        out = jsondata['streams'][0]['height'] if jsondata['streams'][0]['height']
        out = jsondata['streams'][1]['height'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('height')
        out
      end
      outhash['width'] = Util.block do
        out = jsondata['streams'][0]['width'] if jsondata['streams'][0].key?('width')
        out = jsondata['streams'][1]['width'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('width')
        out
      end
      outhash['frame_rate'] = nil
      begin
        outhash['frame_rate'] = calc.evaluate(jsondata['streams'][0]['avg_frame_rate']).to_f.round(2)
        # puts outhash['frame_rate']
      rescue ZeroDivisionError
        outhash['frame_rate'] = nil
      end
      begin
        testvar = calc.evaluate(jsondata['streams'][1]['avg_frame_rate']).to_f.round(2) if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('avg_frame_rate')
        outhash['frame_rate'] = testvar if outhash['frame_rate'].nil? || outhash['frame_rate'] < 1.0
        # puts outhash['frame_rate']
      rescue ZeroDivisionError
        outhash['frame_rate'] = nil if outhash['frame_rate'].nil?
      end
      yield outhash, inputjson if block_given?
      outhash
    end
  end
end
