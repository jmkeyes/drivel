module Blather
  module DSL
    attr_reader :nickname

    def set_nickname name
      @nickname = name
    end

    # Respond to a message from a given context (a Blather Stanza)
    def respond(context, content = nil)
      stanza = context.reply

      # Send to the whole room if the initiator spoke in a conference.
      stanza.to = context.from.stripped if context.type == :groupchat

      # Attach the content of the message, prepending the sender name if the source was a conference.
      stanza.body = (context.type == :groupchat ? "#{context.from.resource}: " : '') + content if content

      # Yield the resulting stanza to a block in case the caller wants to customize the response.
      yield stanza if block_given?

      # Fire it back to the server if the message had either plain or XHTML content.
      client.write stanza unless stanza.body.empty? and stanza.xhtml.empty?
    end

    # Understand a given message, either sent as a prefixed public chat message or a private message.
    def understand(cmd, opts = {})
      regex = /#{Regexp.quote(nickname)}[:, ]? #{cmd.to_s}/

      message :groupchat?, :body => regex do |message|
        parameters = message.body.match(regex).to_a.drop(1)
        yield message, parameters
        true
      end

      message :chat?, :body => cmd do |message|
        parameters = message.body.match(cmd).to_a.drop(1)
        yield message, parameters
        true
      end
    end
  end
end
