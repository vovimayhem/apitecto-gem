# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apitecto/version'

Gem::Specification.new do |spec|
  spec.name          = "apitecto"
  spec.version       = Apitecto::VERSION
  spec.authors       = ["Roberto Quintanilla"]
  spec.email         = ["roberto.quintanilla@gmail.com"]
  spec.summary       = %q{A ruby library for generating REST Api documentation using API Blueprint}
  spec.description   = %q{A ruby library for generating REST Api documentation using API Blueprint}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "matter_compiler", "~> 0.5"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
