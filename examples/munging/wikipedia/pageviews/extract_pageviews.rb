#!/usr/bin/env ruby
# encoding:UTF-8

require 'wukong'
require 'uri'
require 'pathname'
require 'json'
load '/home/dlaw/dev/wukong/examples/wikipedia/munging_utils.rb'

=begin

  Pig output format:
  namespace:int, title:chararray, num_visitors:long, date:int, time:int, epoch_time:long, day_of_week:int
=end

module PageviewsExtractor
  class Mapper < Wukong::Streamer::LineStreamer
    #TODO: Add encoding guard and remove munging utils reference
    
    ns_json = File.open("/home/dlaw/dev/wukong/examples/wikipedia/all_namespaces.json",'r:UTF-8')
    NAMESPACES = JSON.parse(ns_json.read)

  # the filename strings are formatted as
  # pagecounts-YYYYMMDD-HH0000.gz
    def time_from_filename(filename)
      parts = filename.split('-')
      year = parts[1][0..3].to_i
      month = parts[1][4..5].to_i
      day = parts[1][6..7].to_i
      hour = parts[2][0..1].to_i
      return Time.new(year,month,day,hour)
    end

    # grab file name
    def process line
      MungingUtils.guard_encoding(line) do |clean_line|
        next unless clean_line =~ /^en /
        fields = clean_line.split(' ')[1..-1]
        out_fields = []
        # add the namespace
        namespace = nil
        if fields[0].include? ':'
          namespace = NAMESPACES[fields[0].split(':')[0]]
          out_fields << (namespace || '0')
        else
          out_fields << '0'
        end
        # add the title
        if namespace.nil?
          out_fields << URI.unescape(fields[0])
        else
          out_fields << URI.unescape(fields[0][(fields[0].index(':')||-1)+1..-1])
        end
        # add number of visitors in the hour
        out_fields << fields[2]
        # grab date info from filename
        file = Pathname.new(ENV['map_input_file']).basename
        time = time_from_filename(file.to_s)
        out_fields += MungingUtils.time_columns_from_time(time)
        yield out_fields
      end
    end
  end
end

Wukong::Script.new(PageviewsExtractor::Mapper, nil).run
