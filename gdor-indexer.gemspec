# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gdor/indexer/version'

Gem::Specification.new do |spec|
  spec.name          = 'gdor-indexer'
  spec.version       = GDor::Indexer::VERSION
  spec.authors       = ['Naomi Dushay', 'Laney McGlohon', 'Chris Beer']
  spec.email         = ['cabeer@stanford.edu']
  spec.summary       = 'Gryphondor Solr indexing logic'
  spec.homepage      = 'https://github.com/sul-dlss/gdor-indexer'
  spec.license       = 'Apache 2'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'harvestdor-indexer'
  spec.add_dependency 'stanford-mods'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'rsolr'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'mail'
  spec.add_dependency 'hooks'
  spec.add_dependency 'trollop'
  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rdoc'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'equivalent-xml', '~> 0.5'
  spec.add_development_dependency 'capybara'
  spec.add_development_dependency 'poltergeist', '>= 1.5.0'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'jettywrapper'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'pry-byebug'
end
