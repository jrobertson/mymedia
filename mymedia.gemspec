Gem::Specification.new do |s|
  s.name = 'mymedia'
  s.version = '0.5.4'
  s.summary = 'Makes publishing to the web easier'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia.rb']
  s.add_runtime_dependency('dir-to-xml', '~> 1.2', '>=1.2.2')
  s.add_runtime_dependency('dataisland', '~> 0.3', '>=0.3.0')
  s.add_runtime_dependency('increment', '~> 0.1', '>=0.1.4')
  s.add_runtime_dependency('simple-config', '~> 0.7', '>=0.7.2')
  s.add_runtime_dependency('wordsdotdat', '~> 0.2', '>=0.2.0')
  s.signing_key = '../privatekeys/mymedia.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mymedia'
end
