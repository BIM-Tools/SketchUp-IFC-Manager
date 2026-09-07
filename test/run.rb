# frozen_string_literal: true

# Purpose: the one test runner for rake and both CI legs; refuses to pass on zero test files
#
# Rake::TestTask over an empty FileList and `Dir[...].each { require }` over
# nothing both exit 0. This file is what both call instead, and it exits 2 with
# a message when the glob is empty, so a green run always means tests ran.
# Ruby 2.2 syntax: the 2.2 CI leg runs it without Bundler.

dir = ENV['TEST_DIR'] || File.join(File.dirname(__FILE__), 'unit')
files = Dir[File.join(dir, '**', '*_test.rb')].sort
if files.empty?
  warn "test/run.rb: no *_test.rb under #{dir}; refusing to report success on nothing"
  exit 2
end
puts "test/run.rb: #{files.length} test files"
$LOAD_PATH.unshift(File.dirname(__FILE__))
files.each { |f| require File.expand_path(f) }
