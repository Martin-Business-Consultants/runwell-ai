require_relative "lib/runwell_ai/version"

Gem::Specification.new do |spec|
  spec.name = "ai"
  spec.version = RunwellAi::VERSION
  spec.summary = "AI inside Runwell, as a plugin: the Ask panel, suggestions on records, and a queue for agents on runners"
  spec.authors = [ "Runwell" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-ai"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
  spec.add_dependency "ruby_llm", "~> 2.1.1"
end
