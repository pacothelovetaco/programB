# -*- encoding: utf-8 -*-
require File.expand_path('../lib/programb/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Justin Leavitt"]
  gem.email         = ["pacothelovetaco@gmail.com"]
  gem.description   = "An parser built in Ruby for the AIML Markup language."
  gem.summary       = "An AIML interpreter built in Ruby"
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "programb"
  gem.require_paths = ["lib"]
  gem.version       = Programb::VERSION

  gem.add_dependency('nokogiri', '>= 1.6.0')
  gem.add_dependency('minitest')
end
