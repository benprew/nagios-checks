#!/usr/bin/ruby

require 'optparse'
require 'open-uri'
require 'ostruct'
require 'csv'

VERSION = :'3.2.0'

OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3


status = ['OK', 'WARN', 'CRIT', 'UNKN']

@proxies = []
@errors = { OK => [], WARNING => [], CRITICAL => [], UNKNOWN => [] }
options = OpenStruct.new
options.proxies = nil

op = OptionParser.new do |opts|
  opts.banner = 'Usage: check_haproxy.rb [options]'

  opts.separator ''
  opts.separator 'Specific options:'

  # Required arguments
  opts.on("-u", "--url URL", "Statistics URL to check (eg. http://demo.1wt.eu/)") do |v|
    options.url = v
    options.url += ";csv" unless options.url =~ /csv$/
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

  opts.on('-k', '--insecure', 'Allow insecure TLS/SSL connections') do
    options.insecure_ssl = true
  end

  opts.on('--http-error-critical', 'Throw critical when connection to HAProxy is refused or returns error code') do
    options.http_error_critical = true
  end

  opts.on('--cookie [COOKIE]', 'Login/Session cookie') do |v|
    options.cookie = v
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit 3
  end

  opts.on('--version', 'Show version and exit') do
    puts "check_haproxy.rb v#{VERSION}"
    exit 3
  end
end

op.parse!

unless options.url
  puts 'ERROR: URL is required'
  puts op
  exit UNKNOWN
end

if options.warning && !options.warning.to_i.between?(0, 100)
  puts 'ERROR: warning must be between 0 and 100'
  puts op
  exit UNKNOWN
end

if options.critical && !options.critical.to_i.between?(0, 100)
  puts 'ERROR: critical must be between 0 and 100'
  puts op
  exit UNKNOWN
end

if options.warning && options.critical && options.warning.to_i > options.critical.to_i
  puts 'ERROR: warning must be below critical'
  puts op
  exit UNKNOWN
end

def open_options(options)
  open_opts = {
    :http_basic_authentication => [options.user, options.password]
  }
  open_opts['Cookie'] = options.cookie if options.cookie

  # allows https with invalid certificate on ruby 1.9
  # src: http://snippets.aktagon.com/snippets/370-hack-for-using-openuri-with-ssl
  if options.insecure_ssl && RUBY_VERSION =~ /1\.9/
    open_opts[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
  end

  return open_opts
end

def haproxy_response(options)
  tries = 2

  if options.url =~ /https/
    require 'openssl'
    # allows https with invalid certificate on ruby 1.8
    # src: http://snippets.aktagon.com/snippets/370-hack-for-using-openuri-with-ssl
    if options.insecure_ssl && RUBY_VERSION =~ /1\.8/
      OpenSSL::SSL.const_set :VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE
    end
  end

  begin
    return URI.open(options.url, **open_options(options))
  rescue OpenURI::HTTPError => e
    puts "ERROR: #{e.message}"
    options.http_error_critical ? exit(CRITICAL) : exit(UNKNOWN)
  rescue Errno::ECONNREFUSED => e
    puts "ERROR: #{e.message}"
    options.http_error_critical ? exit(CRITICAL) : exit(UNKNOWN)
  rescue RuntimeError => e
    if e.message =~ /redirection forbidden/
      options.url = e.message.gsub(/.*-> (.*)/, '\1')  # extract redirect URL
      retry if (tries -= 1) > 0
      raise
    else
      exit UNKNOWN
    end
  end
end

header = nil

haproxy_response(options).each do |line|
  line !~ line.match?(/redis/)
  if line =~ /^# /
    header = line[2..-1].split(',')
    next
  elsif !header
    puts "ERROR: CSV header is missing: #{line}"
    exit UNKNOWN
  end

  row = header.zip(CSV.parse_line(line)).reduce({}) { |hash, val| hash.merge({val[0] => val[1]}) }

  next if options.proxies && !options.proxies.include?(row['pxname'])
  next if ['statistics', 'admin_stats', 'stats'].include? row['pxname']
  next if row['status'] == 'no check'

  role = %w[BACKEND FRONTEND].include?(row['svname']) || row['bck'].to_i == 0 ? :act : :bck
  if row['slim'].to_i == 0
    session_percent_usage = 0
  else
    session_percent_usage = row['scur'].to_i * 100 / row['slim'].to_i
  end

  proxy_name = sprintf("%s %s (%s) %s", row['pxname'], row['svname'], role, row['status'])
  message = sprintf("%s\tsess=%s/%s(%d%%) smax=%s",
                    proxy_name,
                    row['scur'],
                    row['slim'] || '-1',
                    session_percent_usage,
                    row['smax'])
  @proxies << message

  if role == :act && row['status'] == 'DOWN'
    err_level = row['svname'] == 'BACKEND' ? CRITICAL : WARNING
    @errors[err_level] << message
  end

  if options.critical && session_percent_usage >= options.critical.to_i
    @errors[CRITICAL] << sprintf("%s - too many sessions %s/%s(%d%%)", proxy_name, row['scur'], row['slim'], session_percent_usage)
  elsif options.warning && session_percent_usage >= options.warning.to_i
    @errors[WARNING] << sprintf("%s - too many sessions %s/%s(%d%%)", proxy_name, row['scur'], row['slim'], session_percent_usage)
  end
end

@errors[OK] << "#{@proxies.length} proxies found"

@errors[UNKNOWN] << "No proxies listed as up or down" if @proxies.empty?

[CRITICAL, WARNING, UNKNOWN, OK].each do |exit_code|
  next if @errors[exit_code].empty?

  puts "HAPROXY #{status[exit_code]}: #{@errors[exit_code].join('; ')}"
  puts @proxies.sort
  exit exit_code
end

=begin
Copyright (C) 2013 Ben Prew
Copyright (C) 2013 Mark Ruys, Peercode <mark.ruys@peercode.nl>
Copyright (C) 2015 Hector Sanjuan. Nugg.ad <hector.sanjuan@nugg.ad>
Copyright (C) 2015 Roger Torrentsgeneros <roger.torrentsgeneros@softonic.com>
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
