require 'fileutils'
require 'rake'
require 'rubygems'
require 'rubygems/tasks'
require 'rspec/core/rake_task'

require 'kube_deploy_tools/version'

GEMSERVER = 'https://gemserver.***REMOVED***'

task :default => [:test, :build]

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end

# Push gem to our gem server
Gem::Tasks.new do |tasks|
  tasks.push.host = GEMSERVER
end

# Check if the gem version exists already before pushing the gem
task :check_gem_version_exists do
  check_gem_version_exists = "gem fetch kube_deploy_tools --source #{GEMSERVER} --version #{KubeDeployTools::version_xyz} | grep -q Downloaded"
  system(check_gem_version_exists)
  if $? == 0
    raise "Found gem kube_deploy_tools published to #{GEMSERVER} at version #{KubeDeployTools::version_xyz}. Don't forget to bump the version in lib/kube_deploy_tools/version.rb!"
  end
end
task :push => :check_gem_version_exists

containers_path = 'containers'

# Build Docker images
namespace :container do
  next if !Dir.exists?(containers_path)
  Dir["#{containers_path}/**/Dockerfile"].each do |dockerfile|
    next if dockerfile == '.' || dockerfile == '..'

    container_path = File.dirname(dockerfile)
    container = File.basename(container_path)
    desc "Build Docker image for #{container_path}"
    task container do
      sh "docker build -t local-registry/#{container} -f #{dockerfile} ."
    end

  end
end

# Push Docker images to image registry
namespace :container_push do
  next if !Dir.exists?(containers_path)
  Dir.foreach(containers_path) do |container|
    next if container == '.' || container == '..'

    container_path = File.join(containers_path, container)
    desc "Push Docker image for #{container_path}"
    task container, [:tag] => [:"container:#{container}"]do |t, args|
      cmd = "bundle exec kdt push #{container}"
      cmd += " --tag #{args[:tag]}" if args[:tag]
      sh cmd
    end

  end
end

desc "Push Docker image for kube_deploy_tools at current version"
task :container_publish => [:"container:kube_deploy_tools"] do
  Rake.application.invoke_task("container_push:kube_deploy_tools[#{KubeDeployTools::version_xyz}]")
end
