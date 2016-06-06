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
    def initialize(filename, output, debug = false, vc = nil, vb = nil, vcopts = nil, ac = nil, ab = nil, acopts = nil, af = nil, container = nil, framerate = nil, passes = 2) # rubocop:disable Metrics/ParameterLists
      @nocodec = [nil, 'none', 'copy']

      @vc = nil # initialize variables
      @ac = nil
      @vb = nil
      @ab = nil

      @filepath = Pathname.new(filename)
      @filename = @filepath.realpath.to_s

      @outputpath = Pathname.new(output)
      @output = @outpath.realpath.to_s
      @outfilepath = @outpath.join(@filepath.sub_ext(container).basename)
      @logcmdline = @output.sub(outpath.extname, '')
      @logfile = Pathname.new(@output.sub(outpath.extname, '-0.log'))

      @vc = vc if vc && !vc.in(nocodec) # video codec
      @vb = vb if vb && !vc.in(nocodec) # video bitrate
      @vcopts = vcopts if vcopts && !vc.in(nocodec) # video codec options

      @ac = ac if ac && !ac.in(nocodec) # audio codec
      @ab = ab if ab && !ac.in(nocodec) # audio bitrate
      @acopts = acopts if acopts && !ac.in(nocodec) # audio codec options
      @af = af if af && !ac.in(nocodec) # audio filter

      @mkvpropedit = find_executable('mkvpropedit')
      @ffmpeg = find_executable('ffmpeg')
      @basecmdline = [@ffmpeg, '-i', @filename]

      @framerate = framerate if framerate

      @passes = passes
      @passes = 1 if @vc.in(@nocodec)

      @debug = debug

      raise 'Unable to find ffmpeg, exiting.' unless @ffmpeg
    end

    def commandlist(passmax = nil, passno = nil)
      raise 'passno must be either 1 or 2' unless passno == 1 || passno == 2
      raise 'passmax must be either 1 or 2' unless passmax == 1 || passno == 2
      raise 'passno can not be set if passmax is 1' if !passno.nil? && passmax != 2
      cmd = @basecmdline

      if @vc && !@vc.in(@nocodec)
        ['-c:v', @vc].each do |add|
          cmd << add
        end
      else
        cmd << '-vn'
      end

      if @framerate && !@vc.in(@nocodec)
        ['-filter:v', "fps=#{@framerate}"].each do |add|
          cmd << add
        end
      end

      if !@vc.in(@nocodec) && @vb
        ['-b:v', @vb].each do |add|
          cmd << add
        end
      end

      if passno == 1 && passmax == 2
        ['-pass', '1', '-passlogfile', @logcmdline].each do |add|
          cmd << add
        end
      elsif passno == 2 && passmax == 2
        ['-pass', '2', '-passlogfile', @logcmdline].each do |add|
          cmd << add
        end
      end

      if @ac && !@ac.in(@nocodec) && passno == 2 || passno.nil?
        ['-c:a', @ac].each do |add|
          cmd << add
        end
      else
        cmd << '-an'
      end

      if @ab && !@ac.in(@nocodec)
        ['-b:a', @ab].each do |add|
          cmd << add
        end
      end

      if @af && !@ac.in(@nocodec)
        ['-af', @af].each do |add|
          cmd << add
        end
      end

      ['-hide_banner', '-y'].each do |add|
        cmd << add
      end

      if passno == 1 && passmax == 2
        ['-format', 'matroska', '/dev/null'].each do |add|
          cmd << add
        end
      end

      cmd << @outputfilepath.to_s if passno == 2 || passmax == 1

      cmd.flatten!
      cmd
    end
  end

  def convertdone
    Util::Program.runprogram([@mkvpropedit, '--add-track-statistics-tags', @outfilepath.to_s]) if @container.include?('mkv') || @container.include?('mka')
  end

  def convertnotdone(error)
    Mood.sad('Removing unfinished output file.')
    @outputfilepath.delete
    puts error.message
    raise
  end

  def convert2pass
    if @debug
      puts commandlist(2, 1)
      puts commandlist(2, 2)
    end
    unless @debug
      begin # rubocop:disable Style/RedundantBegin
        Util::Program.runprogram(commandlist(2, 1))
        Util::Program.runprogram(commandlist(2, 2))
      rescue Subprocess::NonZeroExit => e # rubocop:disable Lint/HandleExceptions, Lint/UselessAssignment
        convertnotdone(e)
      else
        convertdone
      ensure
        @logfile.delete
      end
    end
  end

  def convert1pass
    puts commandlist(1) if @debug
    unless @debug
      begin # rubocop:disable Style/RedundantBegin
        Util::Program.runprogram(commandlist(1))
      rescue Subprocess::NonZeroExit => e # rubocop:disable Lint/HandleExceptions, Lint/UselessAssignment
        convertnotdone(e)
      else
        convertdone
      end
    end
  end
end
