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
    def client
      @client ||= Blather::Client.new
    end

    def setup(nickname, *arguments)
      @nickname = nickname
      client.setup(*arguments)
    end

    def run!
      $stdin.reopen "/dev/null"

      [:INT, :TERM].each do |signal|
        trap(sig) { EM.stop }
      end

      EM.run do
        client.run
      end
    end

    def status(state, message = nil)
      state = nil if state == :offline
      client.state = state, message
    end

    def shutdown
      client.close
    end

    def connected(&block)
      handle(:ready, &block)
    end

    def disconnected(&block)
      handle(:disconnected, &block)
    end

    def attend(room, server = nil)
      write_stanza(Blather::Stanza::Presence::MUC) do |stanza|
        conference = room + (server ? '' : '@' + server.to_s)
        stanza.to = conference + '/' + @nickname
      end
    end

    def respond_to(message, content)
      write_stanza(Blather::Stanza::Message) do |stanza|
        stanza.type = message.type
        stanza.from = message.to

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

        yield stanza if block_given?
      end
    end

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

    private
    def write_stanza(klass, *args, &block)
      client.write(klass.new(*args).tap(&block))
    end

    def handle(type, *guards, &block)
      client.register_handler(type, *guards, &block)
    end
  end
end
