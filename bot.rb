#!/usr/bin/env ruby

require 'blather/client'

Dir['./plugins/*.rb'].each do |file|
  puts "[*] Loading plugin from #{file}."
  require file
end

set_nickname 'BlatherBot'

setup 'user@server.com', 'password'

when_ready do
  set_status :available, 'Available'
  puts "[*] Connected as #{jid.stripped}."
  join 'conference@chat.server.com', nickname
end

disconnected do
  set_status nil, 'Departing.'
  puts "\r[*] Disconnecting."
  shutdown
end

subscription :request? do |s|
  puts "[*] Approved subscription request from #{s.from}."
  write_to_stream s.approve!
end

before :message do |m|
  halt if m.delayed? # Ignore messages from the backlog.
  halt if m.body == 'This room is not anonymous.' # Ignore message from server about room visibility.
end

understand /ping/ do |context, parameters|
  respond context, "pong"
end
