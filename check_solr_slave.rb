#!/usr/bin/env ruby

require 'rexml/document'
require 'uri'
require 'net/http'
require 'optparse'
require 'date'

# Set default options
options = {}
options[:hostname] = "localhost"
options[:port] = "8983"
options[:warn] = "15"
options[:crit] = "30"

# Parse command line options
opts = OptionParser.new
opts.on('-H', '--hostname [hostname]', 'Host to connect to [localhost]') do |hostname|
  options[:hostname] = hostname
end

opts.on('-p', '--port [port]', 'Port to connect to [8983]') do |port|
  options[:port] = port
end

opts.on('-w', '--warn [minutes]', 'Threshold for warning [15]') do |warn|
  options[:warn] = warn
end

opts.on('-c', '--crit [minutes]', 'Threshold for critical [30]') do |crit|
  options[:crit] = crit
end

opts.on( '-h', '--help', 'Display this screen' ) do
  puts opts
  exit 3
end
opts.parse!

def get_status_from_uri(uri)
  begin
    res = Net::HTTP.get(uri)
  rescue SocketError => e
    puts "CRITICAL - Unable to contact #{uri}: HTTP #{e}"
    exit 2
  end

  REXML::Document.new(res)
end

def index_version(rexml_doc)
  REXML::XPath.first(rexml_doc, '*//long[@name="replicatableIndexVersion"]').text.to_i
end

solr_slave_status = get_status_from_uri(URI("http://#{options[:hostname]}:#{options[:port]}/solr/replication?command=details"))
solr_master_status = get_status_from_uri(URI(REXML::XPath.first(solr_slave_status, '*//str[@name="masterUrl"]').text + "?command=details"))
replication_time = DateTime.parse(REXML::XPath.first(solr_slave_status, '*//str[@name="indexReplicatedAt"]').text)

# First check to see if we have matching index numbers
# If they don't match, how long since we have succeeded?
current_time = DateTime.now
if index_version(solr_master_status) == index_version(solr_slave_status)
  puts "OK - Slave is current: #{replication_time}"
  exit 0
elsif replication_time > current_time - options[:warn].to_i / 1440.0
  puts "OK - Slave is recent: #{replication_time}"
  exit 0
elsif replication_time < current_time - options[:crit].to_i / 1440.0
  puts "CRITICAL - Slave more than #{options[:crit]} minutes old: #{replication_time}"
  exit 2
elsif replication_time < current_time - options[:warn].to_i / 1440.0
  puts "WARNING - Slave more than #{options[:warn]} minutes old: #{replication_time}"
  exit 1
else
  puts "UNKNOWN - Unable to determine replication status"
  exit 3
end

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
