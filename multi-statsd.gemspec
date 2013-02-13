# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'multi-statsd/version'

Gem::Specification.new do |gem|
  gem.name          = "multi-statsd"
  gem.version       = MultiStatsd::VERSION
  gem.authors       = ["Kelley Reynolds"]
  gem.email         = ["kelley@bigcartel.com"]
  gem.description   = %q{Statsd Server with flexible aggregation and back-end support}
  gem.summary       = %q{Statsd Server with flexible aggregation and back-end support}
  gem.homepage      = "https://github.com/bigcartel/multi-statsd"
  gem.rubyforge_project = "multi-statsd"

  gem.add_dependency "eventmachine"
  gem.add_dependency "em-logger"

  gem.required_ruby_version     = '>= 1.9.3'
  gem.add_development_dependency "bundler", ">= 1.0.0"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "rspec", ">= 2.6.0"
  gem.add_development_dependency "yard", ">= 0.8"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "redis"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
