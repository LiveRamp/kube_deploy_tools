require 'base64'
require 'fileutils'
require 'rake'
require 'rubygems'
require 'rubygems/tasks'
require 'rspec/core/rake_task'

require 'kube_deploy_tools/version'

GEMSERVER = 'https://***REMOVED***'
GEM_CREDENTIALS = ENV['HOME'] + '/.gem/credentials'
VERSION = ENV.fetch('VERSION', '3.0.0.dev')

task :default => [:test, :build]
task :push => [:generate_auto_version, :check_gem_version_exists, :create_artifactory_credentials]

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end

# Push gem to our gem server
Gem::Tasks.new do |tasks|
  tasks.push.host = GEMSERVER
end

# Generate a version_auto.rb file to use in the published gem
task :generate_auto_version do
  File.open('lib/kube_deploy_tools/version_auto.rb') do |f|
    f.write <<-EOH
module KubeDeployTools
  VERSION_XYZ = '#{VERSION}'
end
EOH
  end
end

# Check if the gem version exists already before pushing the gem
task :check_gem_version_exists do
  check_gem_version_exists = "gem fetch kube_deploy_tools --source #{GEMSERVER} --version #{VERSION} | grep -q Downloaded"
  system(check_gem_version_exists)
  if $? == 0
    raise "Found gem kube_deploy_tools published to #{GEMSERVER} at version #{VERSION}. Don't forget to bump the version in lib/kube_deploy_tools/version.rb!"
  end
end

# Create credentials file for pushing gems to artifactory/library
task :create_artifactory_credentials do
  return unless ENV['ARTIFACTORY_USERNAME'] && ENV['ARTIFACTORY_PASSWORD']
  b64_authorization = Base64.encode64("#{ENV['ARTIFACTORY_USERNAME']}:#{ENV['ARTIFACTORY_PASSWORD']}")
  open(GEM_CREDENTIALS, 'w') do |f|
    f.puts "---\n:rubygems_api_key: Basic #{b64_authorization}\n"
  end
  File.chmod 0600, GEM_CREDENTIALS
end
