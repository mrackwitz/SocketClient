Pod::Spec.new do |s|
  s.name               = "SocketShuttle"
  s.version            = '0.1'
  s.summary            = 'A Bayeux client implementation on top of SocketRocket.'
  s.homepage           = 'https://github.com/mrackwitz/SocketShuttle'
  s.authors            = 'Marius Rackwitz, redpixtec. GmbH'
  s.license            = 'MIT License'
  s.source             = { :git => 'https://github.com/mrackwitz/SocketShuttle.git' }
  s.source_files       = 'SocketShuttle/*.{h,m,c}'
  s.requires_arc       = true
  s.ios.frameworks     = %w{Security SystemConfiguration UIKit}
  s.libraries          = "icucore"
  s.documentation = {
    :html => 'http://mrackwitz.github.io/SocketShuttle/doc/index.html',
  }
end
