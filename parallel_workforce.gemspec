lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "parallel_workforce/version"

# rubocop:disable Metrics/BlockLength
Gem::Specification.new do |spec|
  spec.name = "parallel_workforce"
  spec.version = ParallelWorkforce::VERSION
  spec.authors = ["Michael Pearce"]
  spec.email = ["michael.p@enjoy.com"]

  spec.summary = %q{Simplify parallel code execution into workers}
  spec.description = %q{Simplify parallel code execution into workers.}
  spec.homepage = "https://github.com/EnjoyTech/parallel_workforce"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
    spec.metadata["changelog_uri"] = "https://github.com/EnjoyTech/parallel_workforce/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('.', __dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "fakeredis", "~> 0.7"
  spec.add_development_dependency "pry", "~> 0.12"
  spec.add_development_dependency "rails", "~> 4.2"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.8"
  spec.add_development_dependency "rubocop", "~> 0.65"
  spec.add_development_dependency "rubocop-rspec", "~> 1.32"
  spec.add_development_dependency "sidekiq", "~> 4.0"
  spec.add_development_dependency "yajl-ruby", "~> 1.4.1"
end
# rubocop:enable Metrics/BlockLength
