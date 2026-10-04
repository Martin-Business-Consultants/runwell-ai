require_relative "lib/ai/version"

Gem::Specification.new do |spec|
  spec.name = "ai"
  spec.version = Ai::VERSION
  spec.summary = "In-app AI for Runwell, as a plugin"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-ai"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
