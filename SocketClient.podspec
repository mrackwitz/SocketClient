Pod::Spec.new do |s|
  s.name                  = "SocketClient"
  s.version               = '0.1.0'
  s.summary               = 'A Bayeux client implementation on top of SocketRocket.'
  s.homepage              = 'https://github.com/redpeppix-gmbh-co-kg/SocketClient'
  s.authors               = 'Marius Rackwitz, redpixtec. GmbH'
  s.license               = 'MIT License'
  s.source                = { :git => 'https://github.com/redpeppix-gmbh-co-kg/SocketClient.git', :tag => '0.1.0' }
  s.source_files          = 'SocketClient/*.{h,m,c}'
  s.platform              = :ios, '5.0'
  s.requires_arc          = true
  s.ios.frameworks        = %w{Security SystemConfiguration UIKit}
  s.libraries             = "icucore"
  s.dependency            'SocketRocket', :git => 'https://github.com/redpeppix-gmbh-co-kg/SocketRocket.git'
  s.documentation = {
    :html => 'http://redpeppix-gmbh-co-kg.github.io/SocketClient/doc/index.html',
  }
end
