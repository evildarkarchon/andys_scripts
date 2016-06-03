require 'fileutils'
require 'pathname'
require 'subprocess'
require 'mkmf'

require_relative 'videoinfo'
require_relative 'mood'
require_relative 'util'

module ABSConvert
  class Util
    def self.auto_bitrates(database, file)
      vi = VideoInfo::Database.new(Pathname.new(database).realpath.to_s)
      filename = Pathname.new(file).realpath.to_s
      dbinfo = vi.readhash('select bitrate_0_raw, bitrate_1_raw, type_0, type_1 from videoinfo where filename=?', filename)
      bitrates = {}

      bitrates['video'] = dbinfo['bitrate_0_raw'] if dbinfo['type_0'] == 'video'
      bitrates['video'] = dbinfo['bitrate_1_raw'] if dbinfo['type_1'] == 'video'

      bitrates['audio'] = dbinfo['bitrate_0_raw'] if dbinfo['type_0'] == 'audio'
      bitrates['audio'] = dbinfo['bitrate_1_raw'] if dbinfo['type_1'] == 'audio'

      bitrates
    end

    def self.framerate(database, file)
      vi = VideoInfo::Database.new(Pathname.new(database).realpath.to_s)
      filepath = Pathname.new(file).realpath.to_s
      dbinfo = vi.read('select frame_rate from videoinfo where filename = ?', filepath.basename)

      dbinfo
    end

    def self.backup(source, backupdir)
      backuppath = Pathname.new(backupdir)
      sourcepath = Pathname.new(source)

      backup.mkpath unless backuppath.exist?
      raise 'Backup directory is a file.' if backuppath.exist? && backuppath.file?
      sourcepath.rename(backuppath.join(sourcepath.basename)) if sourcepath.exist
    end
  end

  class Convert
    def initialize(filename, output, vc = nil, vb = nil, vcopts = nil, ac = nil, ab = nil, acopts = nil, af = nil, container = nil, framerate = nil, passes = 2) # rubocop:disable Metrics/ParameterLists
      @nocodec = [nil, 'none', 'copy']

      @vc = nil # initialize variables
      @ac = nil
      @vb = nil
      @ab = nil

      @filepath = Pathname.new(filename)
      @filename = @filepath.realpath.to_s

      @outputpath = Pathname.new(output)
      @output = @outpath.realpath.to_s
      @logcmdline = Pathname.new(@output.sub(outpath.extname, ''))
      @logfile = Pathname.new(@output.sub(outpath.extname, '-0.log'))

      @vc = vc if vc && !vc.in(nocodec) # video codec
      @vb = vb if vb && !vc.in(nocodec) # video bitrate
      @vcopts = vcopts if vcopts && !vc.in(nocodec) # video codec options

      @ac = ac if ac && !ac.in(nocodec) # audio codec
      @ab = ab if ab && !ac.in(nocodec) # audio bitrate
      @acopts = acopts if acopts && !ac.in(nocodec) # audio codec options
      @af = af if af && !ac.in(nocodec) # audio filter

      @container = container
      @framerate = framerate

      @mkvpropedit = find_executable('mkvpropedit')
      @ffmpeg = find_executable('ffmpeg')
      @basecmdline = [@ffmpeg, '-i', @filename]

      @framerate = framerate if framerate

      @passes = passes
      @passes = 1 if @vc.in(@nocodec)

      raise 'Unable to find ffmpeg, exiting.' unless @ffmpeg
    end

    def commandlist(passmax = nil, passno = nil)
      raise 'passno must be either 1 or 2' unless passno == 1 || passno == 2
      raise 'passmax must be either 1 or 2' unless passmax == 1 || passno == 2
      raise 'passno can not be set if passmax is 1' if passno && passmax != 2
      cmd = @basecmdline

      if @vc && !@vc.in(@nocodec)
        ['-c:v', @vc].each do |add|
          cmd << add
        end
      else
        cmd << '-vn'
      end
      cmd << ['-filter:v', "fps=#{@framerate}"] if @framerate
      if !@vc.in(@nocodec) && @vb
        ['-b:v', @vb].each do |add|
          cmd << add
        end
      end
      cmd
    end
  end

  def convert2pass
    begin # rubocop:disable Style/RedundantBegin
      Util::Program.runprogram(commandlist(2, 1))
      Util::Program.runprogram(commandlist(2, 2))
    rescue Subprocess::NonZeroExit => e # rubocop:disable Lint/HandleExceptions, Lint/UselessAssignment
      outpath.delete
      puts e.message
    else
      # insert code here
    ensure
      @logfile.delete
    end
  end

  def convert1pass
    begin # rubocop:disable Style/RedundantBegin
      Util::Program.runprogram(commandlist(1))
    rescue Subprocess::NonZeroExit => e # rubocop:disable Lint/HandleExceptions, Lint/UselessAssignment
      outpath.delete
      puts e.message
    else
      # insert code here
    end
  end
end
