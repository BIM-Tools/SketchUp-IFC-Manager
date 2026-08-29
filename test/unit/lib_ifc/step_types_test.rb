# frozen_string_literal: true

# Purpose: pin the STEP serialisation of List, Set and Enumeration containers

require_relative '../../test_helper'

class StepTypesTest < Minitest::Test
  Types = BimTools::IfcManager::Types

  def test_enumeration_is_upcased_and_dotted
    assert_equal '.ELEMENT.', Types::Enumeration.new('element').step
  end

  def test_list_serialises_members_in_order
    list = Types::List.new
    list.add(1)
    list.add(:notdefined)
    list.add(true)
    assert_equal '(1,.NOTDEFINED.,.T.)', list.step
  end

  def test_nil_member_becomes_dollar
    list = Types::List.new
    list.add(nil)
    assert_equal '($)', list.step
  end

  def test_set_drops_duplicates
    set = Types::Set.new
    set.add(7)
    set.add(7)
    assert_equal '(7)', set.step
  end

  def test_string_members_are_passed_through_verbatim
    list = Types::List.new
    list.add("'already quoted'")
    assert_equal "('already quoted')", list.step
  end
end
