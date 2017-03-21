# frozen_string_literal: true
require 'json'
require 'dentaku'
require 'pathname'
require 'filesize'
require 'data_mapper'

begin
  rv = Gem::Version.new(RUBY_VERSION.to_s)
  rvm = Gem::Version.new('2.3.0')
  require 'ruby_dig' if rv < rvm
rescue LoadError
  nil
end

require_relative '../util/recursive_symbolize_keys'

module VideoInfo
  def self.genhash(filename, inputjson, filehash = nil)
    raise 'You must supply either a json string, or a pre-parsed hash' unless inputjson.is_a?(String) || inputjson.is_a?(Hash) || inputjson.is_a?(DataMapper::Collection)
    raise 'filehash must be a Hash or convertable to a hash.' if filehash && !filehash.respond_to?(:to_h)
    filehash = filehash.to_h if filehash && filehash.respond_to?(:to_h) && !filehash.is_a?(Hash)
    filehash.freeze unless filehash.frozen?

    # jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson)).freeze if inputjson.is_a?(String)
    # jsondata = Util.recursive_symbolize_keys(JSON.parse(inputjson[0][:jsondata])).freeze if inputjson.is_a?(DataMapper::Collection)
    # jsondata = Util.recursive_symbolize_keys(inputjson).freeze if inputjson.is_a?(Hash)
    jsondata =
      case
      when inputjson.is_a?(String)
        Util.recursive_symbolize_keys(JSON.parse(inputjson))
      when inputjson.is_a?(DataMapper::Collection)
        Util.recursive_symbolize_keys(JSON.parse(inputjson[0][:jsondata]))
      when inputjson.is_a?(Hash)
        Util.recursive_symbolize_keys(inputjson)
      end
    jsondata.freeze unless jsondata.frozen?

    filepath = Pathname.new(filename)
    filepath.freeze unless filepath.frozen?

    calc = Dentaku::Calculator.new

    fs = lambda do |n|
      # puts n.class
      # puts n.length
      # puts n
      # puts n.to_i.class
      out =
        case
        when n.nil? || n.empty?
          nil
        when n.to_i >= 1_000_000
          Filesize.from(n.to_s + 'b').to('Mb').round(2).to_s + 'Mb/s'
        when n.to_i.between?(1000, 999_999)
          Filesize.from(n.to_s + 'b').to('Kb').round.to_s + 'Kb/s'
        when n.to_i < 1000 && n.to_i >= 1
          n.to_s + 'b/s'
        end
      # puts out
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

    hw = lambda do |i|
      return nil unless jsondata[:streams][0][i] || jsondata[:streams][1][i]
      case
      when jsondata.respond_to?(:dig)
        jsondata.dig(:streams, 1, i) ? jsondata[:streams][1][i] : jsondata[:streams][0][i]
      else
        jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1][i] ? jsondata[:streams][1][i] : jsondata[:streams][0][i]
      end
      # jsondata[:streams][0].is_a?(Hash) && jsondata[:streams][0][i] ? jsondata[:streams][0][i] : nil
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
    outhash[:bitrate_0] = outhash[:bitrate_0_raw] ? fs.call(outhash[:bitrate_0_raw]) : nil
    outhash[:type_0] = jsondata[:streams][0][:codec_type] if jsondata[:streams][0].key?(:codec_type)
    outhash[:codec_0] = jsondata[:streams][0][:codec_name] if jsondata[:streams][0].key?(:codec_name)

    outhash[:bitrate_1_raw] = brr.call(1) if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash)
    outhash[:bitrate_1] = outhash[:bitrate_1_raw] ? fs.call(outhash[:bitrate_1_raw]) : nil
    outhash[:type_1] = jsondata[:streams][1][:codec_type] if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1].key?(:codec_type)
    outhash[:codec_1] = jsondata[:streams][1][:codec_name] if jsondata[:streams][1] && jsondata[:streams][1].is_a?(Hash) && jsondata[:streams][1].key?(:codec_name)

    outhash[:height] = hw.call(:height)
    outhash[:width] = hw.call(:width)

    outhash[:frame_rate] =
      case
      when fr.call(0)
        frc.call(jsondata[:streams][0][:avg_frame_rate])
      when fr.call(1)
        frc.call(jsondata[:streams][1][:avg_frame_rate])
      end
    outhash.freeze
    yield outhash if block_given?
    outhash
  end
end
