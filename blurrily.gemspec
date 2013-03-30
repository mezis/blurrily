# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'blurrily/version'

Gem::Specification.new do |gem|
  gem.name          = "blurrily"
  gem.version       = Blurrily::VERSION
  gem.authors       = ["Julien Letessier"]
  gem.email         = ["julien.letessier@gmail.com"]
  gem.description   = %q{Native fuzzy string search}
  gem.summary       = %q{Native fuzzy string search}
  gem.homepage      = "http://github.com/mezis/blurrily"

  gem.add_dependency 'activesupport'
  gem.add_dependency 'eventmachine'
  gem.add_dependency 'json'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rake-compiler'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-nav'
  gem.add_development_dependency 'pry-doc'
  gem.add_development_dependency 'progressbar'
  gem.add_development_dependency 'benchmark-ips'
  gem.add_development_dependency 'rusage'

  gem.extensions    = ['ext/blurrily/extconf.rb']
  gem.files         = Dir.glob('lib/**/*.rb') +
                      Dir.glob('ext/**/*.{c,h,rb}') +
                      Dir.glob('*.{md,txt}')
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
