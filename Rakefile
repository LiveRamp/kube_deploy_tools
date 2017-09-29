require 'rake'
require 'rubygems'
require 'liveramp_jenkins_tools'

include LiveRamp::Gem_publish
LiveRamp.load_publish_tasks

LiveRamp::Gem_publish.gem_versionfile = './version.rb'
LiveRamp::Gem_publish.gem_to_publish= Gem::Specification.load("rapleaf_types.gemspec")

task :default => [:autopublish]

task :autopublish do
  result = `#{LiveRamp::Gem_publish.tools_binpath}/should_autopublish.rb generic_gem`

  if result =~ /autopublish: TRUE/
    puts "Running 'gem_checks', 'release', to autopublish gem"
    Rake::Task["gem_checks"].invoke
    Rake::Task["release"].invoke
  end
end
