require 'base64'
require 'fileutils'
require 'rake'
require 'rspec/core/rake_task'

task :default => [:test, :build]

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end
