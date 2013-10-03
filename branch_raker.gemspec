# -*- encoding: utf-8 -*-
require File.expand_path( '../lib/branch_raker/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Evan Boyd Sosenko']
  gem.email         = ['razorx@evansosenko.com']
  gem.description   = %q{Use Branch Raker to maintain a build history for each branch. Originally created for LaTeX projects, but useful for anything that needs to be 'compiled'.}
  gem.summary       = %q{Intelligently builds the latest commit on all of your Git branches.}
  gem.homepage      = "http://evansosenko.com"
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'branch_raker'
  gem.require_paths = ['lib']
  gem.platform      = Gem::Platform::RUBY
  gem.version       = BranchRaker::VERSION

  gem.add_dependency 'gitlab-grit'
  gem.add_dependency 'minitar'
  gem.add_dependency 'rake'

  gem.add_development_dependency 'bump'

end
