require 'blather/client/client'

module Drivel
  module DSL
    def set(key, *values)
      if key.is_a?(Hash) and values.empty?
        key.each { |k, v| set(k, v) }
      else
        create_method("#{key}=") { |value| settings[key] = value }
        create_method("#{key}?") { !!settings[key] }
        create_method("#{key}")  { settings[key] }

        settings[key] = values.first
      end
    end

    def configure
      yield
    end

    def helpers(*helpers, &block)
      self.instance_eval(&block) if block_given?
      include(*helpers) unless helpers.empty?
    end

    def before(handler = nil, *guards, &block)
      filter(:before, handler, *guards, &block)
    end

    def after(handler = nil, *guards, &block)
      filter(:after, handler, *guards, &block)
    end

    def connected(&block)
      handle(:ready, &block)
    end

    def disconnected(&block)
      handle(:disconnected, &block)
    end

    def subscription(&block)
      handle(:subscription, &block)
    end

    def command(pattern, *arguments, &block)
      raise InvalidArgumentError unless pattern.is_a?(String) or pattern.is_a?(Regexp)

      safe_nickname   = Regexp.escape(settings[:nickname])
      optional_prefix = /(?:#{safe_nickname}[:,]? |[!$%@])/i

      pattern.gsub!(/((:\w+)|\*)/) do |key|
        (key == '*' ? "(?<splat>.*?)" : "(?<#{key[1..-1]}>[^\s]+)")
      end if pattern.is_a?(String)

      recognize(/\A#{optional_prefix}#{pattern}\Z/, &block)
    end

    def recognize(pattern, *arguments, &block)
      raise InvalidArgumentError unless pattern.is_a?(String) or pattern.is_a?(Regexp)

      matcher = Regexp.compile(pattern.source, Regexp::IGNORECASE)

      handle(:message, :body => matcher) do |message|
        matches  = message.body.match(matcher)
        captures = matches.names.map(&:to_sym).zip(matches.captures)
        yield message, Hash[captures]
      end
    end

    def ready?
      jid? and password? and nickname?
    end

    def run!
      client.setup(settings[:jid], settings[:password])

      # Reopen standard input and direct it at /dev/null.
      $stdin.reopen('/dev/null')

      # Capture interrupt and terminate and force them to shutdown the connection.
      [:INT, :TERM].each do |signal|
        trap(signal) { shutdown }
      end

      # Start.
      EM.run { client.run }
    end

    def status(mode, message)
      mode = nil if mode == :offline
      client.status = mode, message
    end

    def shutdown
      client.close
    end

    def respond(message = nil, content = nil)
      response = ::Blather::Stanza::Message.new.tap do |stanza|
        if message and content
          stanza.type, stanza.from = message.type, message.to

          case message.type
          when :groupchat
            stanza.to   = message.from.stripped
            stanza.body = message.from.resource + ': ' + content
          when :chat
            stanza.to   = message.from
            stanza.body = content
          else
            raise ArgumentError, 'Cannot respond to messages of type ' + message.type.to_s
          end
        end

        # Evaluate any given block, passing in this message before delivery.
        yield stanza if block_given?
      end

      EM.next_tick { client.write(response) }
    end

    def join(conference, password = nil, &block)
      room    = ::Blather::JID.new(conference)
      request = ::Blather::Stanza::Presence::MUC.new.tap do |stanza|
        target = ::Blather::JID.new(room.node, room.domain, settings[:nickname])
        stanza.to, stanza.type = target, nil

        if password.is_a?(String)
          stanza.muc.children = XMPPNode.new('password').tap { |node| node.content = password }
        end
      end
      client.write_with_handler(request, &block)
    end

    def leave(conference, &block)
      room = ::Blather::JID.new(conference)
      request = ::Blather::Stanza::Presence::MUC.new.tap do |stanza|
        target = ::Blather::JID.new(room.node, room.domain, settings[:nickname])
        stanza.to, stanza.type = target, :unavailable
      end
      client.write_with_handler(request, &block)
    end

    def pass
      throw :pass
    end

    def halt
      throw :halt
    end

    def discover(type, target, node = nil, &block)
      stanza = {
        info:  ::Blather::Stanza::DiscoInfo,
        items: ::Blather::Stanza::DiscoItems
      }[type].new

      stanza.node = node
      stanza.from = client.jid
      stanza.to   = target

      client.write_with_handler(stanza, &block)
    end

    def schedule(interval, repeat = true, &block)
      EM.next_tick do
        if repeat
          EM.add_periodic_timer(interval, &block)
        else
          EM.add_timer(interval, &block)
        end
      end
    end

    private
    def settings
      @settings ||= {}
    end

    def client
      @client ||= ::Blather::Client.new
    end

    def handle(type, *guards, &block)
      client.register_handler(type, *guards, &block)
    end

    def filter(type, handler = nil, *guards, &block)
      client.register_filter(type, handler, *guards, &block)
    end

    def create_method(name, *arguments, &block)
      self.class.send(:define_method, name, *arguments, &block)
    end
  end
end
