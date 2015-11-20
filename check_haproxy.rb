#!/usr/bin/ruby

require 'optparse'
require 'open-uri'
require 'ostruct'
require 'csv'

OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

status = ['OK', 'WARN', 'CRIT', 'UNKN']

@proxies = []
@errors = []
@perfdata = []
exit_code = OK

options = OpenStruct.new
options.proxies = []

op = OptionParser.new do |opts|
  opts.banner = 'Usage: check_haproxy.rb [options]'

  opts.separator ""
  opts.separator "Specific options:"

  # Required arguments
  opts.on("-u", "--url URL", "Statistics URL to check (eg. http://demo.1wt.eu/)") do |v|
    options.url = v
    options.url += "/;csv" unless options.url =~ /;/
  end

  # Optional Arguments
  opts.on("-p", "--proxies [PROXIES]", "Only check these proxies (eg. proxy1,proxy2,proxylive)") do |v|
    options.proxies = v.split(/,/)
  end

  opts.on("-U", "--user [USER]", "Basic auth user to login as") do |v|
    options.user = v
  end

  opts.on("-P", "--password [PASSWORD]", "Basic auth password") do |v|
    options.password = v
  end

  opts.on("-w", "--warning [WARNING]", "Pct of active sessions (eg 85, 90)") do |v|
    options.warning = v
  end

  opts.on("-c", "--critical [CRITICAL]", "Pct of active sessions (eg 90, 95)") do |v|
    options.critical = v
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit 3
  end
end

op.parse!

if !options.url
  puts "ERROR: URL is required"
  puts op
  exit UNKNOWN
end

if options.warning && ! options.warning.to_i.between?(0, 100)
  puts "ERROR: warning should be between 0 and 100"
  puts op
  exit UNKNOWN
end

if options.critical && ! options.critical.to_i.between?(0, 100)
  puts "ERROR: critical should be between 0 and 100"
  puts op
  exit UNKNOWN
end

if options.warning && options.critical && options.warning.to_i > options.critical.to_i
  puts "ERROR: warning should be below critical"
  puts op
  exit UNKNOWN
end

open(options.url, :http_basic_authentication => [options.user, options.password]) do |f|
  f.each do |line|

    if line =~ /^# /
      HAPROXY_COLUMN_NAMES = line[2..-1].split(',')
      next
    elsif ! defined? HAPROXY_COLUMN_NAMES
      puts "ERROR: CSV header is missing"
      exit UNKNOWN
    end

    row = HAPROXY_COLUMN_NAMES.zip(CSV.parse(line)[0]).reduce({}) { |hash, val| hash.merge({val[0] => val[1]}) }

    next unless options.proxies.empty? || options.proxies.include?(row['pxname'])
    next if ['statistics', 'admin_stats', 'stats'].include? row['pxname']

    role = row['act'].to_i > 0 ? 'active ' : (row['bck'].to_i > 0 ? 'backup ' : '')
    message = sprintf("%s: %s %s%s", row['pxname'], row['status'], role, row['svname'])
    perf_id = "#{row['pxname']}".downcase

    if row['svname'] == 'FRONTEND'
      session_percent_usage = row['scur'].to_i * 100 / row['slim'].to_i
      @perfdata << "#{perf_id}_sessions=#{session_percent_usage}%;#{options.warning ? options.warning : ""};#{options.critical ? options.critical : ""};;"
      @perfdata << "#{perf_id}_rate=#{row['rate']};;;;#{row['rate_max']}"
      if options.critical && session_percent_usage > options.critical.to_i
        @errors << sprintf("%s has way too many sessions (%s/%s) on %s proxy",
                           row['svname'],
                           row['scur'],
                           row['slim'],
                           row['pxname'])
        exit_code = CRITICAL
      elsif options.warning && session_percent_usage > options.warning.to_i
        @errors << sprintf("%s has too many sessions (%s/%s) on %s proxy",
                           row['svname'],
                           row['scur'],
                           row['slim'],
                           row['pxname'])
        exit_code = WARNING if exit_code == OK || exit_code == UNKNOWN
      end

      if row['status'] != 'OPEN' && row['status'] != 'UP'
        @errors << message
        exit_code = CRITICAL
      end

    elsif row['svname'] == 'BACKEND'
      # It has no point to check sessions number for backends, against the alert limits,
      # as the SLIM number is actually coming from the "fullconn" parameter.
      # So we just collect perfdata. See the following url for more info:
      # http://comments.gmane.org/gmane.comp.web.haproxy/9715
      current_sessions = row['scur'].to_i
      @perfdata << "#{perf_id}_sessions=#{current_sessions};;;;"
      @perfdata << "#{perf_id}_rate=#{row['rate']};;;;#{row['rate_max']}"
      if row['status'] != 'OPEN' && row['status'] != 'UP'
        @errors << message
        exit_code = CRITICAL
      end

    elsif row['status'] != 'no check'
      @proxies << message

      if row['status'] != 'UP'
        @errors << message
        exit_code = WARNING if exit_code == OK || exit_code == UNKNOWN
      else
        session_percent_usage = row['scur'].to_i * 100 / row['slim'].to_i
        @perfdata << "#{perf_id}-#{row['svname']}_sessions=#{session_percent_usage}%;;;;"
        @perfdata << "#{perf_id}-#{row['svname']}_rate=#{row['rate']};;;;#{row['rate_max']}"
      end
    end
  end
end

if @errors.length == 0
  @errors << sprintf("%d proxies found", @proxies.length)
end

if @proxies.length == 0
  @errors << "No proxies listed as up or down"
  exit_code = UNKNOWN if exit_code == OK
end

puts "HAPROXY " + status[exit_code] + ": " + @errors.join('; ') + "|" + @perfdata.join(" ")
puts @proxies

exit exit_code

=begin
Copyright (C) 2013 Ben Prew
Copyright (C) 2013 Mark Ruys, Peercode <mark.ruys@peercode.nl>
Copyright (C) 2015 Hector Sanjuan. Nugg.ad <hector.sanjuan@nugg.ad>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end
