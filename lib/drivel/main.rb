require 'drivel/base'

Object.send(:include, ::Drivel::DSL)
at_exit { run! if ready? }
