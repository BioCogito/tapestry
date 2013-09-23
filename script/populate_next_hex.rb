#!/usr/bin/env ruby

# Default is development
production = ARGV[0] == "production"

verbose = ARGV[1] == "verbose"

ENV["RAILS_ENV"] = "production" if production

require File.dirname(__FILE__) + '/../config/boot'
require File.dirname(__FILE__) + '/../config/environment'

count = 0

if not defined?(SITE_PREFIX) or SITE_PREFIX == 'xx' then
  puts "ERROR: please set SITE_PREFIX to a globally unique value in your environment file"
  exit 1
end

while NextHex.all.count < 1000 do
  begin code = "#{SITE_PREFIX}%06X" % rand(2**24) end while User.unscoped.find_by_hex(code)
  n = NextHex.new()
  n.hex=code
  n.save!
  count += 1
end

if verbose
  puts
  puts "Created #{count} new records in the NextHex table."
  puts
end
