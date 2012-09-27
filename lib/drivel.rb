#!/usr/bin/env ruby

module Drivel
  class Command
    def initialize(pattern, &block)
      @pattern = pattern
      @name    = pattern.slice(/^\w+/)

      @regex   = pattern.gsub(/((:\w+)|\*)/) do |key|
        (key == '*' ? "(?<splat>.*?)" : "(?<#{key[1..-1]}>[^\s]+)")
      end

      self.instance_eval(&block)
    end

    def description(message)
      @description = message
    end

    def action(&block)
      @action = block
    end

    def [](variable)
      case variable
      when :usage
        [ /(help|usage) #{@name}/, @pattern ]
      when :description
        [ /describe #{@name}/, @description ]
      when :action
        [ @regex, @action ]
      end
    end
  end

  module DSL
    # Give direct access to the Blather client.
    def client
      @client ||= Blather::Client.new
    end

    # Setup this bot, capturing it's nickname and passing the rest to Blather.
    def setup(nickname, *arguments)
      @nickname = nickname
      client.setup(*arguments)
    end

    # Don't process this message or send it to another handler.
    def halt
      throw :halt
    end

    # Skip processing this message and send it to the next handler.
    def pass
      throw :pass
    end

    # Set the status of this bot, including a custom away message.
    def status(state, message = nil)
      state = nil if state == :offline
      client.status = state, message
    end

    # Shutdown the bot immediately.
    def shutdown
      client.close
    end

    # Before a message has been processed, evaluate this block passing the message to it.
    def before(handler = nil, *guards, &block)
      client.register_filter(:before, handler, *guards, &block)
    end

    # After a message has been processed, evaluate this block passing the message to it.
    def after(handler = nil, *guards, &block)
      client.register_filter(:after, handler, *guards, &block)
    end

    # When connected, evaluate this block.
    def connected(&block)
      handle(:ready, &block)
    end

    # When disconnected, evaluate this block.
    def disconnected(&block)
      handle(:disconnected, &block)
    end

    # Signal to the server to join a given conference room.
    def attend(room, server = nil)
      write_stanza(Blather::Stanza::Presence::MUC) do |stanza|
        conference = room + (server ? '' : '@' + server.to_s)
        stanza.to = conference + '/' + @nickname
      end
    end

    # Contextually respond to a message, depending on the source, or send a custom message stanza.
    def respond(message = nil, content = nil)
      write_stanza(Blather::Stanza::Message) do |stanza|
        if message
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

        yield stanza if block_given?
      end
    end

    # Install a handler that captures a directed message in either direct or group chat.
    def command(pattern, *arguments, &block)
      raise 'Pattern must respond to :to_s!' unless pattern.respond_to?(:to_s)

      nickname = Regexp.quote(@nickname)
      prefix   = /(?:#{nickname}[:,]? ?|[!$%@])/

      command  = ::Drivel::Command.new(pattern, *arguments, &block)

      install_handler = ->(regex, &callback) {
        handle(:message, :chat? , :body => regex, &callback)
        handle(:message, :groupchat?, :body => regex, &callback)
      }

      command_regex, command_action = command[:action]
      install_handler.call(/^#{prefix}#{command_regex}$/, ->(message) {
        matches = message.body.match(/^#{prefix}#{command_regex}$/)
        parameters = Hash[(matches.names.map(&:to_sym).zip(matches.captures))]
        instance_exec(message, parameters, &command_action)
      })

      usage_regex, usage_message = command[:usage]
      install_handler.call(/^#{prefix}#{usage_regex}$/, ->(message) {
        respond_to(message, usage_message)
      })

      description_regex, description_message = command[:description]
      install_handler.call(/^#{prefix}#{description_regex}$/, ->(message) {
        respond_to(message, description_message)
      })
    end

    # Install a handler that will capture a given pattern in a message.
    def recognize(pattern, *arguments, &block)
      # Unimplemented.
    end

    # Enhance this DSL by adding your own methods or providing a block to evaluate in it's class context.
    def enhance(*addons, &block)
      class_eval(&block) if block_given?
      include(*addons) unless addons.empty?
    end

    # Register modules (or a given block as a module) to include additional functionality
    def register(*plugins, &block)
      plugins << Module.new(&block) if block_given?
      plugins.each { |plugin| include(plugin); plugin.register(self) if plugin.respond_to?(:register) }
    end

    # Run the configured bot now.
    def run!
      $stdin.reopen('/dev/null')

      [:INT, :TERM].each do |signal|
        trap(signal) { client.close }
      end

      EM.run { client.run }
    end

    private
    def write_stanza(klass, *args, &block)
      client.write(klass.new(*args).tap(&block))
    end

    def handle(type, *guards, &block)
      client.register_handler(type, *guards, &block)
    end
  end
end
