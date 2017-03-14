# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi_errorable/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi_errorable"
  spec.version       = JsonapiErrorable::VERSION
  spec.authors       = ["Lee Richmond"]
  spec.email         = ["lrichmond1@bloomberg.net"]

  spec.summary       = %q{jsonapi.org compatible error handling}
  spec.description   = %q{Handles application errors and model validations}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails', [">= 4.1", "< 6"]
  spec.add_dependency 'jsonapi-serializable', '~> 0.1'

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec-rails", "~> 3.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "jsonapi_spec_helpers"
end
