require 'blather/client/client'

module Drivel
  module BasicHelpers
    def halt
      throw :halt
    end

    def pass
      throw :pass
    end

    def roster
      client.roster
    end

    def shutdown
      client.close
    end

    # Broadcast a new XMPP status.
    def status(mode, message)
      # Translate :offline into something Blather will use.
      mode = nil if mode == :offline
      client.status = mode, message
    end

    # Like #say, but prefixed with /me.
    def act(message, options = {})
      raise InvalidArgumentError unless options.has_key?(:to)
    end

    # Send a message to a person or a conference room.
    def say(message, options = {})
      raise InvalidArgumentError unless options.has_key?(:to)
    end

    # Private message a person or a participant in a conference.
    def whisper(message, options = {})
      raise InvalidArgumentError unless options.has_key?(:to)
    end

    # Discover a conference by name and join it.
    def join(conference)
      # Unimplemented.
    end

    # Leave a conference.
    def leave(conference)
      # Unimplemented.
    end

  end

  class Base
    include BasicHelpers

    class << self
      def set(key, values = nil)
        if key.is_a?(Hash) and values.nil?
          key.each { |k, v| set(k, v) }
        else
          settings[key] = values unless values.nil?

          define_singleton_method("#{key}=", proc { |value| settings[key] = value })
          define_singleton_method("#{key}?", proc { !!settings[key] })
          define_singleton_method("#{key}",  proc { settings[key] })
        end
      end

      def configure
        yield settings
      end

      def connected(&block)
        handler(:ready, &block)
      end

      def disconnected(&block)
        handler(:disconnected, &block)
      end

      def subscription(&block)
        handler(:subscription, &block)
      end

      def before(handler = nil, *guards, &block)
        filter(:before, handler, *guards, &block)
      end

      def after(handler = nil, *guards, &block)
        filter(:after, handler, *guards, &block)
      end

      def error(*errors, &block)
        # Unimplemented.
      end

      def command(pattern, &block)
        # Unimplemented.
      end

      def recognize(pattern, *arguments, &block)
        # Unimplemented.
      end

      def ready?
        # At minimum, we need :jid and :password.
        true
      end

      def run!
        # Don't run unless everything's kosher.
        raise InvalidArgumentError unless ready?

        define_method(:client,   proc { self.class.client })
        define_method(:settings, proc { self.class.settings })

        # Reopen standard input and direct it at /dev/null.
        $stdin.reopen('/dev/null')

        # Capture interrupt and terminate and force them to shutdown the connection.
        [:INT, :TERM].each do |signal|
          trap(signal) { client.close }
        end

        # Setup the Blather client.
        client.setup(jid, password)

        # Get started.
        EM.run { client.run }
      end

      private
      def settings
        @settings ||= {}
      end

      def client
        @client ||= ::Blather::Client.new
      end

      def handler(type, *guards, &block)
        client.register_handler(type, *guards, &block)
      end

      def filter(type, handler = nil, *guards, &block)
        client.register_filter(type, handler, *guards, &block)
      end
    end
  end
end
