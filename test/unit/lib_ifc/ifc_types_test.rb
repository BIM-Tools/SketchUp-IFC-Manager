# frozen_string_literal: true

# Purpose: pin STEP string escaping and the scalar IFC value types

require_relative '../../test_helper'

class IfcTypesTest < Minitest::Test
  Types = BimTools::IfcManager::Types

  def setup
    BimTools::IfcManager.reset_export_messages
  end

  def test_replace_char_escapes_quote_and_backslash
    assert_equal 'it\\X\\27s', Types.replace_char("it's")
    assert_equal 'a\\X\\5Cb', Types.replace_char('a\\b')
  end

  def test_replace_char_keeps_plain_ascii
    assert_equal 'Wall 01', Types.replace_char('Wall 01')
  end

  def test_replace_char_encodes_bmp_characters_as_x2
    assert_equal '\\X2\\0100\\X0\\', Types.replace_char('Ā')
  end

  def test_real_drops_trailing_zero_but_keeps_the_point
    assert_equal '1.', Types::IfcReal.new(nil, 1.0).step
    assert_equal '2.5', Types::IfcReal.new(nil, 2.5).step
  end

  def test_real_long_form_wraps_in_type_name
    assert_equal 'IFCREAL(1.)', Types::IfcReal.new(nil, 1, true).step
  end

  def test_boolean_accepts_strings_and_reports_garbage
    assert_equal '.T.', Types::IfcBoolean.new(nil, 'true').step
    assert_equal '.F.', Types::IfcBoolean.new(nil, false).step
    assert_equal '$', Types::IfcBoolean.new(nil, 'maybe').step
    assert_equal 1, BimTools::IfcManager.export_messages.length
  end

  def test_compound_plane_angle_validates_components
    assert_equal '(52,5,30)', Types::IfcCompoundPlaneAngleMeasure.new(nil, [52, 5, 30]).step
    assert_raises(ArgumentError) { Types::IfcCompoundPlaneAngleMeasure.new(nil, [52, 61, 0]) }
    assert_raises(ArgumentError) { Types::IfcCompoundPlaneAngleMeasure.new(nil, [-52, 5, 0]) }
  end

  def test_identifier_is_truncated_to_255_with_a_message
    id = Types::IfcIdentifier.new(nil, 'x' * 300)
    assert_equal 255, id.value.length
    assert_equal 1, BimTools::IfcManager.export_messages.length
  end

  def test_date_requires_a_datetime
    assert_raises(TypeError) { Types::IfcDate.new(nil, '2026-08-29') }
    assert_equal "'2026-08-29'", Types::IfcDate.new(nil, DateTime.new(2026, 8, 29)).step
  end
end
