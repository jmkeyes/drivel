#!/usr/bin/env ruby

require 'drivel'

include Drivel::DSL

setup 'DrivelBot', 'user@example.com', 'secretpassword'

connected do
  status :available, 'At your service.'
end

disconnected do
  status :offline, 'Going away.' and shutdown
end

command 'ping' do
  description 'Respond with a pong message to test.'
  action do |message, options|
    respond message, "pong"
  end
end

run!
