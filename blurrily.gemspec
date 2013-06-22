# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'blurrily/version'

Gem::Specification.new do |gem|
  gem.name          = "blurrily"
  gem.version       = Blurrily::VERSION
  gem.authors       = ["Julien Letessier", "Dawid Sklodowski", "Marcus Mitchell"]
  gem.email         = ["julien.letessier@gmail.com"]
  gem.description   = %q{Native fuzzy string search}
  gem.summary       = %q{Native fuzzy string search}
  gem.homepage      = "http://github.com/mezis/blurrily"

  gem.add_dependency 'activesupport'
  gem.add_dependency 'eventmachine'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rake-compiler'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-nav'
  gem.add_development_dependency 'pry-doc'
  gem.add_development_dependency 'progressbar'
  gem.add_development_dependency 'benchmark-ips'
  gem.add_development_dependency 'guard'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'terminal-notifier-guard'
  gem.add_development_dependency 'coveralls'

  gem.extensions    = ['ext/blurrily/extconf.rb']
  gem.files         = Dir.glob('lib/**/*.rb') +
                      Dir.glob('ext/**/*.{c,h,rb}') +
                      Dir.glob('*.{md,txt}') +
                      Dir.glob('bin/blurrily')
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
