#!/usr/bin/env ruby

require 'blather/client/client'

module Drivel
  # Create instances to handle commands, extracting colon-prefixed and wildcard arguments as parameters.
  class Command
    def initialize(pattern, &block)
      @pattern = pattern
      @name    = pattern.slice(/^\w+/)
      @regex   = pattern.gsub(/((:\w+)|\*)/) do |key|
        (key == '*' ? "(?<splat>.*?)" : "(?<#{key[1..-1]}>[^\s]+)")
      end

      # Evaluate any command block in the context of this instance.
      self.instance_eval(&block) if block_given?
    end

    # Define a descriptive message to help a user understand what this command is for.
    def description(message)
      @description = message
    end

    # Define the action for when this command is called.
    def action(&block)
      @action = block
    end

    # Provide access to regex-value pairs by overriding array access.
    def [](variable)
      case variable
      when :usage # Display a usage message.
        [ /(help|usage) #{@name}/, @pattern ]
      when :description # Display a command description message.
        [ /describe #{@name}/, @description ]
      when :action # Evaluate the action block defined for this command
        [ @regex, @action ]
      end
    end
  end

  # Include Drivel::DSL in any script you'd like to setup your bot to use.
  module DSL
    # Define #nickname on the object, so we have access to it externally.
    attr_reader :nickname

    # Convert a string into a JID, or return ours.
    def jid(from = nil)
      from ? ::Blather::JID.new(from) : client.jid
    end

    # Give direct access to the Blather client.
    def client
      @client ||= ::Blather::Client.new
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
      write_stanza(::Blather::Stanza::Presence::MUC) do |stanza|
        conference = room + (server ? '' : '@' + server.to_s)
        stanza.to = conference + '/' + nickname
      end
    end

    # Contextually respond to a message, depending on the source, or send a custom message stanza.
    def respond(message = nil, content = nil)
      write_stanza(Blather::Stanza::Message) do |stanza|
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
    end

    # Install a handler that captures a directed message in either direct or group chat.
    def command(pattern, *arguments, &block)
      raise 'Pattern must respond to :to_s!' unless pattern.respond_to?(:to_s)

      nick   = Regexp.quote(nickname)
      prefix = /(?:#{nick}[:,]? ?|[!$%@])/

      command = ::Drivel::Command.new(pattern, *arguments, &block)

      install_handler = ->(regex, &callback) {
        handle(:message, :chat? , :body => regex, &callback)
        handle(:message, :groupchat?, :body => regex, &callback)
      }

      # Install a handler for this command that will evaluate it's action block when called.
      command_regex, command_action = command[:action]
      install_handler.call /^#{prefix}#{command_regex}$/ do |message|
        matches = message.body.match(/^#{prefix}#{command_regex}$/)
        parameters = Hash[(matches.names.map(&:to_sym).zip(matches.captures))]
        instance_exec(message, parameters, &command_action)
      end

      # Install a handler to send a help/usage message when called.
      usage_regex, usage_message = command[:usage]
      install_handler.call /^#{prefix}#{usage_regex}$/ do |message|
        respond_to(message, usage_message)
      end

      # Install a handler to send a descriptive message when called. TODO: Maybe roll this into help/usage later.
      description_regex, description_message = command[:description]
      install_handler.call /^#{prefix}#{description_regex}$/ do |message|
        respond_to(message, description_message)
      end
    end

    # Install a handler that will capture a given pattern in a message.
    def recognize(pattern, *arguments, &block)
      raise 'Recognizing general messsage content is currently unimplemented.'
    end

    # Register modules (or a given block as a module) to include additional functionality
    def register(*plugins, &block)
      # Turn an anonymous block into a plugin definition.
      plugins << Module.new(&block) if block_given?
      # Register any defined plugins by extending this instance with their methods and calling #register on them.
      plugins.each { |plugin| extend(plugin); plugin.register(self) if plugin.respond_to?(:register) }
    end

    # Run the configured bot now.
    def run!
      # Reopen standard input and direct it at /dev/null.
      $stdin.reopen('/dev/null')

      # Capture interrupt and terminate and force them to shutdown the connection.
      [:INT, :TERM].each do |signal|
        trap(signal) { client.close }
      end

      # Get started.
      EM.run { client.run }
    end

    private
    # Create a new instance of a class, passing any arguments, and evaluate it in the context of any passed block.
    def write_stanza(klass, *args, &block)
      client.write(klass.new(*args).tap(&block))
    end

    # Register a handler for this type of message, using blather's guards to test if the handler applies to a message.
    def handle(type, *guards, &block)
      client.register_handler(type, *guards, &block)
    end
  end
end
