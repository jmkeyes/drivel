Gem::Specification.new do |spec|
  spec.name        = 'drivel'
  spec.version     = '0.0.1'

  spec.authors     = ['Joshua Keyes']
  spec.email       = 'joshua.michael.keyes@gmail.com'

  spec.license     = 'MIT'
  spec.summary     = %q{A DSL for building XMPP bots.}
  spec.description = %q{An alternative DSL utilizing the excellent XMPP library, Blather, for creating interactive XMPP bots.}

  spec.files       = Dir['lib/**/*.rb', 'README.md']

  spec.add_dependency 'blather', '>= 0.8.0'
end
