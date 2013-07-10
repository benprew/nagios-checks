#!/usr/local/bin/ruby
require 'optparse'
require 'open-uri'
require 'ostruct'
require 'csv'

OK = 0
WARNING = 1
CRITICAL = 2

@messages = []
exit_code = OK

options = OpenStruct.new
options.proxies = []

opts = OptionParser.new do |opts|
  opts.banner = 'Usage: check_haproxy.rb [options]'

  opts.separator ""
  opts.separator "Specific options:"

  # Required arguments

  opts.on("-u", "--url URL", "URL to check") do |v|
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
end

opts.parse!

if !options.url
  puts "ERROR: URL is required"
  puts opts
  exit
end

open(options.url, http_basic_authentication: [options.user, options.password]) do |f|
  CSV.new(f, headers: :first_row).each do |row|
    next unless options.proxies.empty? || options.proxies.include?(row['# pxname'])
    next if row['svname'] == 'BACKEND'

    if row['status'] == 'UP'
      puts sprintf("%s '%s' is UP on '%s' proxy!", (row['act'] == 1 ? 'Active' : 'Backup'), row['svname'], row['# pxname'])
    end

    if row['status'] == 'DOWN'
      @messages << sprintf("%s '%s' is DOWN on '%s' proxy!", (row['act'] == 1 ? 'Active' : 'Backup'), row['svname'], row['# pxname'])
      exit_code = CRITICAL
    end
  end
end

puts @messages
exit exit_code

