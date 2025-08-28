# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'fixd_utils'
  spec.version = '1.2.5'
  spec.authors = ['Charles Julian Knight']
  spec.email = ['julian@fixdapp.com']

  spec.summary = 'Small utility classes for use at FIXD.'
  spec.description = <<~DESC
    This is a collection of small utility classes that are useful in Ruby and Rails
    applications at FIXD.
  DESC
  spec.homepage = 'https://git.fixdapp.com/open-source/ruby-fixd-utils'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['allowed_push_host'] = '_'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/-/blob/main/CHANGELOG"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'after_commit_everywhere', '~> 1.3.0'
  spec.add_dependency 'pg', '>= 1.3', '< 2'
  spec.add_dependency 'rails', '>= 6.0', '< 8.0'
  spec.add_dependency 'redis-semaphore', '~> 0.3.1'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
