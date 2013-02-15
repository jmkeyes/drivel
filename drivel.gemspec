# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'drivel/version'

Gem::Specification.new do |gem|
  gem.name          = "drivel"
  gem.version       = Drivel::VERSION

  gem.authors       = ["Joshua M. Keyes"]
  gem.email         = ["joshua.michael.keyes@gmail.com"]

  gem.description   = %q{An alternative DSL utilizing the excellent XMPP library, Blather, for creating interactive XMPP bots.}
  gem.summary       = %q{A DSL for building XMPP bots.}
  gem.homepage      = "https://github.com/jmkeyes/drivel"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'blather', '= 0.8.1'
end
