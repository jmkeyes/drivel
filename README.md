Drivel
======
An alternative DSL utilizing the excellent XMPP library, Blather, for creating interactive XMPP bots.

Example
-------

    #!/usr/bin/env ruby

    require 'drivel'

    include Drivel::DSL

    setup 'DrivelBot', 'user@example.com', 'secretpassword'

    connected do
      status :available, 'At your service.'
      attend 'room@conference.example.com'
    end

    disconnected do
      status :offline, 'Going away.' and shutdown
    end

    command 'ping' do
      description 'Respond with a pong message to test.'
      action do |message, options|
        respond message, 'pong'
      end
    end

    run!

Feedback
--------
Patches welcome.

