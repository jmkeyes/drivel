# Drivel

An alternative DSL utilizing the excellent XMPP library, Blather, for creating interactive XMPP bots.

## Installation

Add this line to your application's Gemfile:

    gem 'drivel'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install drivel

## Usage

TBD.

## Example

    #!/usr/bin/env ruby

    require 'drivel'

    configure do
      # Do basic setup/configuration.
      set nickname: 'DrivelBot', jid: 'username@chat.example.com/resource', password: 'secretpassword'

      # (Optional) conferences to discover and join.
      set :conferences, 'main', 'offtopic'
    end

    helpers do
      def authorized?(context)
        context.chat? and message.from == 'owner@example.com'
      end
    end

    connected do
      status :available, 'At your service.'
    end

    disconnected do
      status :offline, 'Going away now.' and shutdown
    end

    subscription do |message|
      # Handle subscription messages like Blather would.
    end

    command 'ping' do |message|
      respond message, 'pong'
    end

    command 'join :conference' do |message, params|
      respond message, "I'm afraid I can't do that." and halt unless authorized?(message)
      join params[:conference]
    end

    command 'leave :conference' do |message, params|
      respond message, "I'm afraid I can't do that." and halt unless authorized?(message)
      leave params[:conference]
    end

    recognize 'What is love?' do |message|
      respond message, "Baby don't hurt me no more."
    end

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
