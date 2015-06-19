Gem::Specification.new do |s|
  s.name = 'mymedia'
  s.version = '0.2.6'
  s.summary = 'Makes publishing to the web easier'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('dynarex', '~> 1.2', '>=1.3.1') 
  s.add_runtime_dependency('sps-pub', '~> 0.4', '>=0.4.0') 
  s.add_runtime_dependency('dir-to-xml', '~> 0.3', '>=0.3.3')
  s.add_runtime_dependency('dataisland', '~> 0.1', '>=0.1.14')
  s.add_runtime_dependency('increment', '~> 0.1', '>=0.1.4')
  s.add_runtime_dependency('simple-config', '~> 0.2', '>=0.2.1') 
  s.signing_key = '../privatekeys/mymedia.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/mymedia'
end
