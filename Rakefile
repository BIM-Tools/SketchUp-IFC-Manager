# frozen_string_literal: true
# Purpose: single entry point for lint, syntax check and unit tests

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/unit/**/*_test.rb']
  t.warning = false
end

desc 'Run RuboCop with the SketchUp cops'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Syntax-check every Ruby file under src/ with the current interpreter'
task :syntax do
  files = FileList['src/**/*.rb'].exclude('src/bt_ifcmanager/lib/rubyzip*/**/*')
  files.each { |f| ruby '-c', f, verbose: false }
end

task default: %i[rubocop test]
