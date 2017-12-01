require 'rake'
require 'rubygems'
require 'rubygems/tasks'
require 'rspec/core/rake_task'

task :default => [:test, :build]

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  t.rspec_opts = '--format documentation'
end

Gem::Tasks.new do |tasks|
  tasks.push.host = 'https://gemserver.***REMOVED***'
end
