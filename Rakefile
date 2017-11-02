require 'rake'
require 'rubygems'
require 'rspec/core/rake_task'
require 'liveramp_jenkins_tools'
require 'liveramp_updater'

include LiveRamp::Gem_publish
include LiverampUpdater
LiveRamp.load_publish_tasks

task :default do
  Rake::Task[:test].invoke
end

task :autopublish do
  puts 'Setting gem_versionfile...'
  LiveRamp::Gem_publish.gem_versionfile = './version.rb'
  puts LiveRamp::Gem_publish.gem_versionfile

  puts 'Setting gem_name...'
  gemspec = Gem::Specification.load("kube_deploy_tools.gemspec")
  LiveRamp::Gem_publish.gem_name = gemspec.name
  puts LiveRamp::Gem_publish.gem_name

  result = `#{LiveRamp::Gem_publish.tools_binpath}/should_autopublish.rb generic_gem`
  puts "Should autopublish: #{result}"
  if result =~ /autopublish: TRUE/
    Rake::Task["update_gem"].invoke
    Bundler::GemHelper.install_tasks
    Rake::Task["release"].invoke
  end
end

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

