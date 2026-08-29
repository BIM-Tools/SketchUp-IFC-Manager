# frozen_string_literal: true

# Purpose: pin the IFC base64 GUID compression and its round trip to hex and UUID

require_relative '../../test_helper'

class IfcGloballyUniqueIdTest < Minitest::Test
  Guid = BimTools::IfcManager::IfcGloballyUniqueId

  def test_new_guid_is_22_characters_from_the_ifc_alphabet
    text = Guid.new.to_s
    assert_equal 22, text.length
    assert_match(/\A[0-9A-Za-z_$]{22}\z/, text)
  end

  def test_step_form_is_single_quoted
    guid = Guid.new
    assert_equal "'#{guid}'", guid.step
  end

  def test_all_zero_hex_compresses_to_all_zero_text
    guid = Guid.new
    guid.instance_variable_set(:@hex_guid, '0' * 32)
    assert_equal '0' * 22, guid.to_s
  end

  def test_compressed_text_round_trips_to_the_same_hex
    guid = Guid.new
    assert_equal guid.to_hex, guid.ifc_guid_to_hex(guid.to_s)
  end

  def test_to_uuid_inserts_hyphens_in_the_8_4_4_4_12_layout
    guid = Guid.new
    guid.instance_variable_set(:@hex_guid, '0123456789abcdef0123456789abcdef')
    assert_equal '01234567-89ab-cdef-0123-456789abcdef', guid.to_uuid
  end

  def test_unformat_guid_accepts_uuid_and_compressed_forms
    guid = Guid.new
    hex = '0123456789abcdef0123456789abcdef'
    assert_equal hex, guid.unformat_guid('01234567-89ab-cdef-0123-456789abcdef')
    guid.instance_variable_set(:@hex_guid, hex)
    assert_equal hex, guid.unformat_guid(guid.to_s)
  end
end
