#!/usr/bin/env ruby
# aur_json
# Query the Arch User Repository Remote Procedure Call interface
# Copyright (c) 2013 Boohbah <boohbah at gmail.com>

require 'net/http'
require 'json'
require 'pp'

# Return a hash with results value of an array of hashes of results
# https://wiki.archlinux.org/index.php/AurJson
def aur_json type, arg
  unless %w(search msearch info multiinfo).include? type
    abort "ERROR: Unknown query type #{type}"
  end
  # The rpc.php script on the server will handle other errors
  base = "https://aur.archlinux.org/rpc.php?type="
  uri = URI("#{base}#{type}&arg=#{arg}")

  Net::HTTP.start(uri.host, uri.port,
    :use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new uri
    response = http.request request
    JSON.parse response.body
  end
end

pp aur_json(ARGV[0], ARGV[1])
