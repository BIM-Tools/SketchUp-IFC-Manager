# frozen_string_literal: true
# Purpose: single entry point for lint, the Ruby 2.2 compat check and unit tests

desc 'Run the unit tests through the one runner (exits 2 on zero test files)'
task :test do
  ruby 'test/run.rb'
end

desc 'Run RuboCop with the SketchUp cops'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Fail on Ruby APIs missing from 2.2 (SketchUp 2017) or removed by 3.2 (SketchUp 2024+)'
task :compat do
  require_relative 'test/support/compat_rules'
  files = FileList['src/**/*.rb'].exclude('src/bt_ifcmanager/lib/rubyzip*/**/*')
  hits = CompatRules.scan(files)
  unless hits.empty?
    warn hits.join("\n")
    raise "compat: #{hits.size} hit(s); each line names the Ruby version rule it breaks"
  end
  puts "compat: #{files.size} files, 0 hits"
end

task default: %i[rubocop compat test]
