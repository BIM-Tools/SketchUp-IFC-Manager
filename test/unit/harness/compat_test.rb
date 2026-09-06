# frozen_string_literal: true

# Purpose: prove the Ruby-version denylist fires on the APIs that shipped broken

require 'tempfile'
require 'minitest/autorun'
require_relative '../../support/compat_rules'

class CompatTest < Minitest::Test
  def hits_for(source)
    Tempfile.create(['compat', '.rb']) do |f|
      f.write(source)
      f.flush
      CompatRules.scan([f.path])
    end
  end

  def test_unary_plus_string_is_a_hit
    assert_equal 1, hits_for("x = +''\n").length
  end

  def test_delete_prefix_is_a_hit
    assert_equal 1, hits_for("s.delete_prefix('a')\n").length
  end

  def test_removed_in_32_is_a_hit
    assert_equal 1, hits_for("File.exists?('x')\n").length
  end

  def test_dup_is_clean
    assert_equal [], hits_for("x = ''.dup\n")
  end

  def test_hit_names_file_line_and_reason
    hit = hits_for("s.delete_prefix('a')\n").first
    assert_match(/:1: Ruby 2\.5: s\.delete_prefix/, hit)
  end
end
