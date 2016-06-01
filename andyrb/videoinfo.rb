require 'sqlite3'
require 'json'
require 'pathname'
require 'filesize'
require 'filemagic'
require 'find'
# rubocop:disable Style/MultilineOperationIndentation
# insert documentation here
module VideoInfo
  CreateStatement = 'CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, type_0 text, bitrate_1 text, bitrate_0_raw integer, bitrate_1_raw integer, type_1 text, codec_0 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'.freeze
  CreateStatementJSON = 'CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'.freeze

  def self.find(directory, printresults = false)
    magic = FileMagic.new
    directories = []
    Find.find(directory) do |path|
      result = magic.file(path) if FileTest.file?(path)
      pathpath = Pathname.new(path)
      directories << pathpath.dirname if result && result.to_s.include?('SQLite 3.x') && !pathpath.extname.include?('.bak') && !pathpath.extname.include?('.test')
      # puts path if result && result.to_s.include?('SQLite 3.x database')
    end
    if printresults
      directories.each do |path|
        puts "'#{path}'"
      end
    end
    directories
  end

  class Database
    def initialize(dbpath = Pathname.new('./videoinfo.sqlite'))
      @db = SQLite3::Database.new(dbpath.to_s)
      @db.type_translation = true
      @db.auto_vacuum= true unless @db.auto_vacuum # rubocop:disable Style/RedundantPartheses, Style/SpaceAroundOperators
      @db.cache_size= -2000 unless @db.cache_size <= -2000 # rubocop:disable Style/RedundantPartheses, Style/SpaceAroundOperators
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
      output
    end

    def readhash(query, *values)
      @db.results_as_hash = true
      inputvalues = values.to_a if values.respond_to?(:to_a)
      output = @db.execute(query, inputvalues)
      output = nil if output.empty?
      @db.results_as_hash = false
      output
    end

    def createvitable
      @db.execute CreateStatement
      @db.execute 'vacuum'
    end

    def createjsontable
      @db.execute CreateStatementJSON
      @db.execute 'vacuum'
    end
  end

  class Generate
    def initialize(dbpath = Pathname.new('./videoinfo.sqlite'))
      @vi = Database.new(dbpath.to_s)
    end

    def query(inputhash)
      columns = inputhash[0].keys.join(', ')
      placeholders = inputhash[0].keys.join(':' + ', :')
      viquery = "insert into videoinfo (#{columns}) values ({#{placeholders})"
      jsondata = JSON.parse(inputhash[1])
      jsondata['format']['filename'] = File.basename(jsondata['format']['filename'])
      @vi.write(viquery, inputhash[0])
      @vi.write('insert into videojson (filename, jsondata) values (?, ?)', jsondata['format']['filename'], inputhash[1]) if @vi.read('select filename from videojson where filename = ?', jsondata['format']['filename']).empty?
    end

    def json(filename)
      output = nil
      testresult = @vi.read('select filename from videojson where filename = ?', filename)
      output = testresult unless testresult.empty?
      output = IO.popen(['ffprobe', '-i', filename, '-hide_banner', '-of', 'json', '-show_streams', '-show_format', '-loglevel', 'quiet']) if testresult.empty?
      output
    end

    def hash(filename, inputjson, filehash)
      jsondata = JSON.parse(inputjson)
      filepath = Pathname.new(filename)
      outhash = {}

      outhash['filename'] = filepath.basename
      outhash['hash'] = filehash
      outhash['container'] = jsondata['format']['formatname']
      outhash['duration'] = Time.at(jsondata['format']['duration']).utc.strftime('%H:%M:%S')
      outhash['duration_raw'] = jsondata['format']['duration']
      outhash['streams'] = jsondata['format']['nb_streams']

      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to_s + 'Kb/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'] >= 1000
      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['bit_rate'].to_s + 'b').to_s + 'b/s' if jsondata['streams'][0].key?('bit_rate') && jsondata['streams'][0]['bit_rate'] < 1000

      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['tags']['BPS'].to_s + 'b').to_s + 'Kb/s' \
      if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags'] >= 1000
      outhash['bitrate_0'] = Filesize.from(jsondata['streams'][0]['tags']['BPS'].to_s + 'b').to_s + 'b/s' if jsondata['streams'][0].key?('tags') && \
      jsondata['streams'][0]['tags'].key?('BPS') && jsondata['streams'][0]['tags'] < 1000

      outhash['bitrate_0_raw'] = jsondata['streams'][0]['bitrate'] if jsondata['streams'][0].key?('bitrate')
      outhash['bitrate_0_raw'] = jsondata['streams'][0]['tags']['BPS'] if jsondata['streams'][0].key?('tags') && jsondata['streams'][0]['tags'].key?('BPS')

      outhash['type_0'] = jsondata['streams'][0]['codec_type'] if jsondata['streams'][0].key?('codec_type')
      outhash['codec_0'] = jsondata['streams'][0]['codec_name'] if jsondata['streams'][0].key?('codec_name')

      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Kb').to_s + 'Kb/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'] >= 1000
      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['bit_rate'].to_s + 'b').to('Kb').to_s + 'b/s' if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('bit_rate') && jsondata['streams'][1]['bit_rate'] < 1000

      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Kb').to_s + 'Kb/s' if jsondata['streams'].length >= 2 && \
      jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS') && \
      jsondata['streams'][1]['tags']['BPS'] >= 1000
      outhash['bitrate_1'] = Filesize.from(jsondata['streams'][1]['tags']['BPS'].to_s + 'b').to('Kb').to_s + 'b/s' if jsondata['streams'].length >= 2 && \
      jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS') && \
      jsondata['streams'][1]['tags']['BPS'] < 1000

      outhash['bitrate_1_raw'] = jsondata['streams'][1]['bit_rate'] if jsondata['streams'][1].key?('bit_rate')
      outhash['bitrate_1_raw'] = jsondata['streams'][1]['tags']['BPS'] if jsondata['streams'][1].key?('tags') && jsondata['streams'][1]['tags'].key?('BPS')

      outhash['type_1'] = jsondata['streams'][1]['codec_type'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('codec_type')
      outhash['codec_1'] = jsondata['streams'][1]['codec_name'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('codec_name')

      outhash['height'] = jsondata['streams'][0]['height'] if jsondata['streams'][0]['height']
      outhash['height'] = jsondata['streams'][1]['height'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('height')
      outhash['width'] = jsondata['streams'][0]['width'] if jsondata['streams'][0].key?('width')
      outhash['width'] = jsondata['streams'][1]['width'] if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('width')

      outhash['frame_rate'] = nil
      begin
        outhash['frame_rate'] = jsondata['streams'][0]['frame_rate'].to_f if jsondata['streams'][0].key?('frame_rate') && jsondata['streams'][0]['frame_rate'].responds_to(:to_f) && jsondata['streams'][0]['frame_rate'].to_f >= 1.0
        outhash['frame_rate'] = jsondata['streams'][1]['frame_rate'].to_f if jsondata['streams'].length >= 2 && jsondata['streams'][1].key?('frame_rate') && jsondata['streams'][1]['frame_rate'].to_f >= 1.0
      rescue ZeroDivisionError
        outhash['frame_rate'] = nil
      end

      return outhash, inputjson # rubocop:disable Style/RedundantReturn
    end
  end
end
