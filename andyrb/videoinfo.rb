require 'sqlite3'
require 'json'
require 'pathname'
# insert documentation here
module VideoInfo
  CreateStatement = 'CREATE TABLE IF NOT EXISTS videoinfo (id integer primary key, filename text unique, duration text, duration_raw real, streams integer, bitrate_total text, bitrate_0 text, bitrate_1 text, bitrate_0_raw integer, bitrate_1_raw integer, codec_0 text, codec_1 text, container text, width integer, height integer, frame_rate real, hash text unique)'.freeze
  CreateStatementJSON = 'CREATE TABLE IF NOT EXISTS videojson (id INTEGER PRIMARY KEY, filename TEXT UNIQUE, jsondata JSON)'.freeze
  class Database
    def initialize(dbpath = Pathname.new('./videoinfo.sqlite'))
      @db = SQLite3::Database.new(dbpath.to_s)
      @db.type_translation = true
      @db.auto_vacuum = true if @db.auto_vacuum is false
      @db.cache_size = -2000 if @db.cache_size > -2000
    end

    def write(query, *values)
      dbvalues = values.to_a if values.responds_to?(:to_a)
      @db.execute(SQLite3::Database.quote(query), dbvalues)
    end

    def writenp(query, inputhash)
      inputhash.to_h if inputhash.respond_to?(:to_h)

      @db.execute(query, inputhash)
    end

    def read(query, *values)
      inputvalues = values.to_a if values.responds_to?(:to_a)
      output = @db.execute(SQLite3::Database.quote(query), inputvalues)
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
      columns = inputhash.keys.join(', ')
      placeholders = inputhash.keys.join(':' + ', :')
      viquery = "insert into videoinfo (#{columns}) values ({#{placeholders})"
      @vi.write(viquery, inputhash)
    end

    def json(filename)
      output = nil
      testresult = @vi.read('select filename from videojson where filename = ?', filename)
      if testresult
        output = testresult
      else
        output = IO.popen(['ffprobe', '-i', filename, '-hide_banner', '-of', 'json', '-show_streams', '-show_format', '-loglevel', 'quiet'])
      end
      output
    end

    def genhash(filename, inputjson, filehash)
      jsondata = json.parse(inputjson)
      filepath = Pathname.new(filename)
      outhash = {}

      outhash['filename'] = filepath.basename
      outhash['hash'] = filehash
      outhash['container'] = jsondata['format']['formatname']

      return outhash, inputjson # rubocop:disable Style/RedundantReturn
    end
  end
end
