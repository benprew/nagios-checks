#!/usr/local/bin/ruby

require 'optparse'
require 'open-uri'
require 'ostruct'
require 'csv'

OK = 0
WARNING = 1
CRITICAL = 2

HAPROXY_COLUMN_NAMES = %w{pxname svname qcur qmax scur smax slim stot bin bout dreq dresp ereq econ eresp wretr wredis status weight act bck chkfail chkdown lastchg downtime qlimit pid iid sid throttle lbtot tracked type rate rate_lim rate_max check_status check_code check_duration hrsp_1xx hrsp_2xx hrsp_3xx hrsp_4xx hrsp_5xx hrsp_other hanafail req_rate req_rate_max req_tot cli_abrt srv_abrt}

@messages = []
exit_code = OK

options = OpenStruct.new
options.proxies = []

op = OptionParser.new do |opts|
  opts.banner = 'Usage: check_haproxy.rb [options]'

  opts.separator ""
  opts.separator "Specific options:"

  # Required arguments

  opts.on("-u", "--url URL", "csv-formatted stats URL to check (http://demo.1wt.eu/;csv") do |v|
    options.url = v
  end

  # Optional Arguments

  opts.on("-p", "--proxies [PROXIES]", "Only check these proxies (eg proxy1,proxy2,proxylive)") do |v|
    options[:proxies] = v.split(/,/)
  end

  opts.on("-U", "--user [USER]", "basic auth USER to login as") do |v|
    options.user = v
  end

  opts.on("-P", "--password [PASSWORD]", "basic auth PASSWORD") do |v|
    options.password = v
  end

  opts.on("-d", "--[no-]debug", "include debug output") do |v|
    options.debug = v
  end
end

op.parse!

if !options.url
  puts "ERROR: URL is required"
  puts op
  exit
end

open(options.url, :http_basic_authentication => [options.user, options.password]) do |f|
  f.each do |line|

    row = HAPROXY_COLUMN_NAMES.zip(CSV.parse(line)[0]).reduce({}) { |hash, val| hash.merge({val[0] => val[1]}) }

    next unless options.proxies.empty? || options.proxies.include?(row['pxname'])
    next if row['svname'] == 'BACKEND'

    if row['status'] == 'UP' && options.debug
      puts sprintf("%s '%s' is UP on '%s' proxy!", (row['act'] == 1 ? 'Active' : 'Backup'), row['svname'], row['pxname'])
    end

    if row['status'] == 'DOWN'
      @messages << sprintf("%s '%s' is DOWN on '%s' proxy!", (row['act'] == 1 ? 'Active' : 'Backup'), row['svname'], row['pxname'])
      exit_code = CRITICAL
    end
  end
end

puts @messages
exit exit_code

=begin
Copyright (C) 2013 Ben Prew

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
