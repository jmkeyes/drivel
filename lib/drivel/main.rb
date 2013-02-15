require 'drivel/base'

module Drivel
  at_exit { Base.run! if Base.ready? }
end

# extend Drivel::Base won't work, obviously.
