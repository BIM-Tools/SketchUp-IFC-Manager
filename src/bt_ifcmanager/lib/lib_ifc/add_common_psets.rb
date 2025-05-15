# frozen_string_literal: true

#  add_common_psets.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.

require 'rexml/document'
include REXML

module BimTools
  module IfcManager
    # Finds and adds common propertyset for definition IFC type
    #
    # @param [Sketchup::ComponentDefinition] definition
    # @param [String] ent_type_name
    def add_common_psets(definition, ent_type_name)
      ifc_dict = definition.attribute_dictionary(Settings.ifc_version)
      return unless ifc_dict

      # Ensure the "PropertySets" dictionary exists
      property_sets_dict = ensure_property_sets_dict(ifc_dict)

      entity_type = Settings.ifc_module.const_get(ent_type_name)
      entity_type.ancestors.each do |ancestor|
        process_ancestor(ancestor, property_sets_dict)
      end

      false
    end

    private

    # Ensures the "PropertySets" dictionary exists and sets its attributes
    def ensure_property_sets_dict(ifc_dict)
      property_sets_dict = ifc_dict.attribute_dictionary('PropertySets', true)
      ifc_dict.set_attribute('PropertySets', 'is_hidden', false)
      property_sets_dict
    end

    # Processes an ancestor and adds property sets if applicable
    def process_ancestor(ancestor, property_sets_dict)
      split_name = ancestor.name.split('::Ifc')
      return unless split_name.length == 2

      basename = split_name.last
      return if basename.end_with?('_su')

      filename = File.join(PLUGIN_PATH_LIB, 'lib_ifc', 'psd', "Pset_#{basename}Common.xml")
      return unless File.file?(filename)

      add_property_sets_from_file(filename, property_sets_dict)
    end

    # Adds property sets from an XML file
    def add_property_sets_from_file(filename, property_sets_dict)
      xmlfile = File.new(filename)
      xmldoc = Document.new(xmlfile)

      xmldoc.elements.each('PropertySetDef') do |property_set_element|
        propertyset_name = property_set_element.elements['Name']
        propertyset_name = propertyset_name.text if propertyset_name
        next unless propertyset_name

        pset_dict = property_sets_dict.attribute_dictionary(propertyset_name, true)
        property_sets_dict.set_attribute(propertyset_name, 'is_hidden', false)
        process_property_definitions(property_set_element, pset_dict)
      end
    end

    # Processes property definitions within a property set
    def process_property_definitions(property_set_element, pset_dict)
      property_set_element.elements.each('PropertyDefs/PropertyDef') do |property_def_element|
        property_name = property_def_element.elements['Name']
        property_name = property_name.text if property_name
        property_type_element = property_def_element.elements['PropertyType']
        if property_type_element && property_type_element.elements.first
          property_type = property_type_element.elements.first.name
        end
        next unless property_name && property_type

        # Only add TypePropertySingleValue and TypePropertyEnumeratedValue
        # Possible property value types
        # - TypePropertySingleValue
        # - TypePropertyEnumeratedValue : "choice"?
        # - TypePropertyBoundedValue
        # - TypePropertyReferenceValue

        case property_type
        when 'TypePropertySingleValue'

          # Possible sketchup value types
          # - boolean
          # - choice
          # - long # integer?
          # - double
          # - string
          handle_single_value_property(property_def_element, pset_dict, property_name)
        when 'TypePropertyEnumeratedValue'
          handle_enumerated_value_property(property_def_element, pset_dict, property_name)
        end
      end
    end

    # Handles TypePropertySingleValue properties
    def handle_single_value_property(property_def_element, pset_dict, property_name)
      value_type_element = property_def_element.elements['PropertyType/TypePropertySingleValue/DataType']
      value_type = value_type_element.attributes['type'] if value_type_element
      return unless value_type

      attribute_type = determine_attribute_type(value_type)
      pset_dict.attribute_dictionary(property_name, true)
      pset_dict.set_attribute(property_name, 'is_hidden', false)
      pset_dict.set_attribute(property_name, 'ifc_type', value_type)
      pset_dict.set_attribute(property_name, 'attribute_type', attribute_type)
      pset_dict.set_attribute(property_name, 'value', nil)
    end

    # Handles TypePropertyEnumeratedValue properties
    def handle_enumerated_value_property(property_def_element, pset_dict, property_name)
      value_type_element = property_def_element.elements['PropertyType/TypePropertyEnumeratedValue/EnumList']
      value_type = value_type_element.attributes['name'] if value_type_element
      options = []
      if value_type_element
        value_type_element.get_elements('EnumItem').each do |enum_item|
          options << enum_item.text
        end
      end
      return unless value_type && !options.empty?

      pset_dict.attribute_dictionary(property_name, true)
      pset_dict.set_attribute(property_name, 'is_hidden', false)
      pset_dict.set_attribute(property_name, 'attribute_type', 'enumeration')
      pset_dict.set_attribute(property_name, 'options', options)
      pset_dict.set_attribute(property_name, 'value', options.last)
    end

    # Determines the attribute type based on the value type
    def determine_attribute_type(value_type)
      case value_type
      when 'IfcBoolean'
        # value = false
        'boolean'
      when 'IfcInteger'
        # value = 0
        'long'
      when /Measure/
        # value = 0.0
        'double'
      else
        # value = ""
        'string'
      end
    end
  end
end
