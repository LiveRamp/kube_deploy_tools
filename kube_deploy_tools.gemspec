require 'date'
require File.expand_path('version.rb')

Gem::Specification.new do |gem|
  gem.name    = 'kube_deploy_tools'
  gem.version = KubeDeployTools::VERSION
  gem.date    = Date.today.to_s

  gem.summary = "Kubernetes Deploy Tools"
  gem.description = "Kubernetes deploy tools for LiveRamp"

  gem.authors  = ['ops']
  gem.email    = 'ops@***REMOVED***'
  gem.homepage = 'http://git.***REMOVED***/OpsRepos/kube_deploy_tools'

  gem.add_dependency 'colorize', '~> 0.8'
  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'

  # ensure the gem is built out of versioned files
  gem.files = Dir['Rakefile', '{bin,lib}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")
  gem.executables = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.require_paths = ['lib']
end
