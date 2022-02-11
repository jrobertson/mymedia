Gem::Specification.new do |s|
  s.name = 'mymedia'
  s.version = '0.5.0'
  s.summary = 'Makes publishing to the web easier'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia.rb']
  s.add_runtime_dependency('dynarex', '~> 1.9', '>=1.9.2')
  s.add_runtime_dependency('sps-pub', '~> 0.5', '>=0.5.5')
  s.add_runtime_dependency('dir-to-xml', '~> 1.0', '>=1.0.8')
  s.add_runtime_dependency('dataisland', '~> 0.3', '>=0.3.0')
  s.add_runtime_dependency('increment', '~> 0.1', '>=0.1.4')
  s.add_runtime_dependency('simple-config', '~> 0.7', '>=0.7.2')
  s.signing_key = '../privatekeys/mymedia.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mymedia'
end
