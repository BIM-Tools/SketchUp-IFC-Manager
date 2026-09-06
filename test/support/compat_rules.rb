# frozen_string_literal: true

# Purpose: Ruby APIs missing from 2.2 (SketchUp 2017) or removed by 3.2 (SketchUp 2024+)
#
# ruby -c on 2.2 catches syntax; it cannot catch a method that does not exist
# yet, and six such sites shipped broken from 2022 to 2026. Each entry names the
# version so the failure message is the rule. A false positive is removed here
# with a comment saying why, never worked around at the call site.

module CompatRules
  RULES = [
    [/(?<![\w)\]'"])\+['"]/, 'String#+@ is Ruby 2.3'],
    [/\.(delete_prefix|delete_suffix)\b/, 'Ruby 2.5'],
    [/\.dig\(/, 'Ruby 2.3'],
    [/\.(transform_values|transform_keys)\b/, 'Ruby 2.4 / 2.5'],
    [/\.(yield_self|then)\b/, 'Ruby 2.5 / 2.6'],
    [/\.(clamp|sum|match\?|unpack1|casecmp\?)\b/, 'Ruby 2.4'],
    [/\.(filter_map|tally)\b/, 'Ruby 2.7'],
    [/\.(fetch_values|grep_v)\b/, 'Ruby 2.3'],
    [/SecureRandom\.alphanumeric|keyword_init|Dir\.each_child/, 'Ruby 2.5'],
    [/File\.exists\?|Dir\.exists\?|\bFixnum\b|\bBignum\b|\.untaint\b|\$SAFE/, 'removed in Ruby 3.2'],
    [/URI\.(escape|encode|decode)\b/, 'removed in Ruby 3.0']
  ].freeze

  # Returns "file:line: reason: source" per hit, so the failure names the rule.
  def self.scan(paths)
    hits = []
    paths.each do |path|
      File.foreach(path).with_index(1) do |line, n|
        RULES.each do |re, why|
          hits << "#{path}:#{n}: #{why}: #{line.strip}" if line =~ re
        end
      end
    end
    hits
  end
end
