require 'fileutils'
require 'rake'
require 'rspec/core/rake_task'

task :default => [:test, :build]

task :build do
  cmd = 'gem build kube_deploy_tools.gemspec'
  system(cmd)
  if $? != 0 then raise "#{cmd} failed with exit status #{$?}" end
end

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end
