# frozen_string_literal: true

# Purpose: shared test bootstrap, loads the pure lib_ifc layer without SketchUp

require 'English'
require 'minitest/autorun'
require_relative 'support/ifc_manager_stub'

LIB_IFC = File.expand_path('../src/bt_ifcmanager/lib/lib_ifc', __dir__)

# Files that must load with no Sketchup or Geom constant defined. Adding a file here is a
# promise; pure_layer_loads_test proves it in a clean interpreter.
PURE_FILES = %w[
  step.rb
  step_types.rb
  ifc_types.rb
  IfcGloballyUniqueId.rb
  spatial_structure.rb
].freeze

PURE_FILES.each { |f| require File.join(LIB_IFC, f) }
