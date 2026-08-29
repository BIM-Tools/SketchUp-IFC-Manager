# frozen_string_literal: true

# Purpose: prove the pure lib_ifc files load in a clean Ruby with no SketchUp constants

require_relative '../../test_helper'

class PureLayerLoadsTest < Minitest::Test
  def test_pure_files_load_without_sketchup
    stub = File.expand_path('../../support/ifc_manager_stub.rb', __dir__)
    script = PURE_FILES.map { |f| "require #{File.join(LIB_IFC, f).inspect}" }.join(';')
    program = "require #{stub.inspect};#{script};" \
              'exit(defined?(Sketchup) || defined?(Geom) ? 1 : 0)'
    output = `#{Gem.ruby} -e #{program.inspect} 2>&1`
    assert $CHILD_STATUS.success?, "pure layer failed to load cleanly:\n#{output}"
  end
end
