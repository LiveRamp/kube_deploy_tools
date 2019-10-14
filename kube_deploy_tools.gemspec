require 'date'
require File.expand_path(File.join('lib', 'kube_deploy_tools', 'version.rb'))

Gem::Specification.new do |gem|
  gem.name    = 'kube_deploy_tools'
  gem.version = KubeDeployTools::VERSION
  gem.date    = Date.today.to_s

  gem.summary = "Kubernetes Deploy Tools"
  gem.description = "Kubernetes deploy tools for LiveRamp"

  gem.authors  = ['ops']
  gem.email    = 'ops@***REMOVED***'
  gem.homepage = 'https://github.com/LiveRamp/kube_deploy_tools'
  gem.license  = 'MIT'

  gem.required_ruby_version = '>= 2.3'

  gem.add_dependency 'colorize', '~> 0.8'
  gem.add_dependency 'artifactory', '~> 2.0'
  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rspec_junit_formatter', '~> 0.4.1'

  # ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib}/**/*', 'README*', 'LICENSE*']
  gem.executables = ['kdt']
  gem.require_paths = ['lib']
end
