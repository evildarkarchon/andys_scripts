require 'sqlite3'
require 'json'
require 'pathname'
require 'filesize'
require 'filemagic'
require 'find'
require 'subprocess'
require 'dentaku'
# rubocop:disable Style/MultilineOperationIndentation, Performance/StringReplacement, Style/CommentIndentation
# insert documentation here
require_relative 'mood'
module VideoInfo
  CreateStatement = 'CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_0_raw integer, type_0 text, codec_0 text, bitrate_1 text, bitrate_1_raw integer, type_1 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'.freeze
  CreateStatementJSON = 'CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'.freeze

  def self.find(directory)
    magic = FileMagic.new
    dirpath = Pathname.new(directory)
    initdirectories = Dir.glob("#{directory}/**/*.sqlite")
    directories = []
    initdirectories.each do |i|
      result = magic.file(i) if FileTest.file?(i)
      dirpath = Pathname.new(i).realpath
      initdirectories.delete(i) unless result.include?('SQLite 3.x')
      next unless result.include?('SQLite 3.x')
      directories << dirpath.to_s
    end
    # blacklist = ['.webm', '.mkv', '.flv', '.vob', '.ogg', '.drc', '.avi', '.wmv', '.yuv', '.rm', '.rmvb', '.asf', '.mp4', '.m4v', '.mpg', '.mp2', '.mpeg', '.mpe', '.mpv', '.3gp', '.3g2', '.mxf', '.roq', '.nsv', '.f4v', '.wav', '.ra', '.mka', '.jpg', '.jpeg', '.gif', '.png']
=begin
    directories = Find.find(directory).select do |path|
      result = magic.file(path) if FileTest.file?(path)
      dbpath = Pathname.new(path)
      puts dbpath
      result.to_s.include?('SQLite 3.x') && !dbpath.extname.include?('.bak') && !dbpath.extname.include?('.test')
    end
=end
    yield directories if block_given?
    directories
  end

  class Database
    def initialize(dbpath = './videoinfo.sqlite')
      @dbpath = Pathname.new(dbpath)
      @dbpath = @dbpath.realpath if @dbpath.exist?
      @db = SQLite3::Database.new(@dbpath.to_s)
      @db.type_translation = true
      @db.auto_vacuum= true unless @db.auto_vacuum # rubocop:disable Style/SpaceAroundOperators
      @db.cache_size= -2000 unless @db.cache_size <= -2000 # rubocop:disable Style/SpaceAroundOperators
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
      output
    end

    def readhash(query, *values)
      @db.results_as_hash = true
      inputvalues = values.to_a if values.respond_to?(:to_a)
      output = @db.execute(query, inputvalues)
      output = nil if output.empty?
      @db.results_as_hash = false
      return output[0] if output.is_a?(Array) && output.length == 1
      output
    end

    def query(input, *values)
      var = @db.execute(input, values)
      var
    end

    def querynp(input, **values)
      var = @db.execute(input, values)
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

    def write(inputhash, inputjson, verbose = false)
      columns = inputhash.keys.to_a.join(', ').gsub(':', '').gsub('[', '').gsub(']', '')
      # placeholders = ''
      # inputhash[0].keys.each do |key|
      #  placeholders + key.to_sym.to_s
      # end
      # placeholders.to_s.gsub('[', '').gsub(']', '')
      # puts placeholders.to_s
      jsondata = JSON.parse(inputjson)
      placeholders = ':' + inputhash.keys.join(', :')
      viquery = "insert into videoinfo (#{columns}) values (#{placeholders})"
      if verbose
        puts viquery
        puts inputhash
      end
      begin
        puts Mood.happy { "Writing metadata for #{jsondata['format']['filename']}" }
        @vi.write(viquery, inputhash)
      rescue SQLite3::SQLException => e
        @rtvcount += 1
        puts Mood.neutral { 'VideoInfo table not found, creating and retrying.' }
        @vi.createvitable
        puts Mood.neutral { "Try \##{@rtvcount}" } if verbose == true
        retry if @rtvcount <= 5
      end
      # query = @db.prepare("insert into videoinfo (filename, duration, duration_raw, streams, bitrate_total, bitrate_0, bitrate_0_raw, type_0, codec_0, bitrate_1, bitrate_1_raw, type_1, codec_1, container, width, height, frame_rate, hash) values (:filename, :duration, :duration_raw, :streams, :bitrate_total, :bitrate_0, :bitrate_0_raw, :type_0, :codec_0, :bitrate_1, :bitrate_1_raw, :type_1, :codec_1, :container, :width, :height, :frame_rate, :hash)")
      # query.bind_params(inputhash)
      # query.execute
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

    def self.filelist(filelist, testmode = false)
      whitelist = ['video/x-flv', 'video/mp4', 'video/mp2t', 'video/3gpp', 'video/quicktime', 'video/x-msvideo', 'video/x-ms-wmv', 'video/webm', 'video/x-matroska', 'video/msvideo', 'video/avi', 'application/vnd.rm-realmedia', 'audio/x-pn-realaudio', 'audio/x-matroska', 'audio/ogg', 'video/ogg', 'audio/vorbis', 'video/theora', 'video/3gpp2', 'audio/x-wav', 'audio/wave', 'video/dvd', 'video/mpeg', 'application/vnd.rn-realmedia-vbr', 'audio/vnd.rn-realaudio', 'audio/x-realaudio']
      magic = FileMagic.new(:mime_type)
      sortlist = Util::SortEntries.sort(filelist)
      # existinghash = nil if existinghash.nil? || existinghash.empty?
      puts 'Files to be examined:' if testmode
      outlist = []
      sortlist.each do |entry|
        if testmode
          puts magic.flags
          puts magic.file(entry)
        end
        # outlist << entry if whitelist.include?(magic.file(entry)) && existinghash.respond_to?(:keys) && !entry.in?(existinghash.keys) && !testmode
        # if !existinghash || existinghash.nil? || existinghash.empty?
        outlist << entry if whitelist.include?(magic.file(entry)) && !testmode
        # end
        puts Mood.happy { entry } if whitelist.include?(magic.file(entry)) && testmode
      end
      magic.close
      outlist = Util::SortEntries.sort(outlist)
      yield outlist if block_given?
      outlist
    end

=begin
    def self.digest(filelist)
      outhash = {}
      filelist.each do |file|
        outhash[file] = Util.hashfile(file)
      end
      outhash
    end
=end

    def json(filename, verbose = false)
      output = nil
      testresult = nil
      file = Pathname.new(filename).realpath
      begin
        testresult = @vi.read('select jsondata from videojson where filename = ?', File.basename(filename)).to_s
      rescue SQLite3::SQLException
        @vi.createjsontable
        @rtjcount += 1
        puts Mood.neutral "Try \##{@rtjcount}" if verbose == true
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
        puts output if verbose == true
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
      outhash['bitrate_total'] = Filesize.from(jsondata['format']['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i >= 1_000_000
      outhash['bitrate_total'] = Filesize.from(jsondata['format']['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i.between?(1000, 999_999)
      outhash['bitrate_total'] = jsondata['format']['bit_rate'].to_s + 'b/s' if jsondata['format'].key?('bit_rate') && jsondata['format']['bit_rate'].to_i < 1000

      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'].to_i >= 1_000_000
      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'].to_i.between?(1000, 999_999)
      outhash['bitrate_0'] = jsondata['streams'][0]['bit_rate'].to_s + 'b/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'].to_i < 1000

      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['tags']['BPS'].to_s + 'b').to('Kb').to_s + 'Kb/s' \
      if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags']['BPS'].to_i >= 1000
      outhash['bitrate_0'] = jsondata['streams'][0]['tags']['BPS'].to_s + 'b/s' if jsondata['streams'][0].key?('tags') && \
      jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags']['BPS'].to_i < 1000

      outhash['bitrate_0_raw'] = jsondata['streams'][0]['bit_rate'] if jsondata['streams'][0].key?('bit_rate')
      outhash['bitrate_0_raw'] = jsondata['streams'][0]['tags']['BPS'] if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS')

      outhash['type_0'] = jsondata['streams'][0]['codec_type'] if jsondata['streams'][0].key?('codec_type')
      outhash['codec_0'] = jsondata['streams'][0]['codec_name'] if jsondata['streams'][0].key?('codec_name')

      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i >= 1_000_000
      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i.between?(1000, 999_999)
      outhash['bitrate_1'] = jsondata['streams'][1]['bit_rate'].to_s + 'b/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'].to_i < 1000

      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Mb').round(2).to_s + 'Mb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('tags') && \
      jsondata['streams'][1]['tags'].key?('BPS') && jsondata['streams'][1]['tags']['BPS'].to_i >= 1_000_000
      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Kb').round.to_s + 'Kb/s' if jsondata['streams'].length >= 2 && \
      jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS') && \
      jsondata['streams'][1]['tags']['BPS'].to_i.between?(1000, 999_999)
      outhash['bitrate_1'] = jsondata['streams'][1]['tags']['BPS'].to_s + 'b/s' if jsondata['streams'].length >= 2 && \
      jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS') && \
      jsondata['streams'][1]['tags']['BPS'].to_i < 1000

      outhash['bitrate_1_raw'] = jsondata['streams'][1]['bit_rate'] if jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('bit_rate')
      outhash['bitrate_1_raw'] = jsondata['streams'][1]['tags']['BPS'] if jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS')

      outhash['type_1'] = jsondata['streams'][1]['codec_type'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('codec_type')
      outhash['codec_1'] = jsondata['streams'][1]['codec_name'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('codec_name')

      outhash['height'] = jsondata['streams'][0]['height'] if jsondata['streams'][0]['height']
      outhash['height'] = jsondata['streams'][1]['height'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('height')
      outhash['width'] = jsondata['streams'][0]['width'] if jsondata['streams'][0].key?('width')
      outhash['width'] = jsondata['streams'][1]['width'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].respond_to?(:key) && jsondata['streams'][1].key?('width')
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
