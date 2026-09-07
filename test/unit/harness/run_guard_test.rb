# frozen_string_literal: true

# Purpose: prove test/run.rb goes red on an empty test directory

require 'open3'
require 'tmpdir'
require 'minitest/autorun'

class RunGuardTest < Minitest::Test
  def test_empty_directory_exits_two
    runner = File.expand_path('../../run.rb', __dir__)
    Dir.mktmpdir do |empty|
      # The child gets TEST_DIR in its own environment; setting it in this
      # process would point minitest's own autorun at the empty directory.
      output, status = Open3.capture2e({ 'TEST_DIR' => empty }, Gem.ruby, runner)
      assert_equal 2, status.exitstatus, output
      assert_match(/no \*_test\.rb/, output)
    end
  end
end
