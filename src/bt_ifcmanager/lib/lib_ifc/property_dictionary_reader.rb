# frozen_string_literal: true

#  property_dictionary_reader.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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
#
#

require_relative 'ifc_types'
require_relative 'ifc_property_builder'
require_relative 'ifc_rel_defines_by_properties_builder'

module BimTools
  module IfcManager
    # Collects the needed attributes for an IfcProperty from
    # a nested Sketchup AttributeDictionary structure
    class PropertyDictionaryReader
      attr_reader :name, :value, :ifc_type, :ifc_type_name, :attribute_type, :options

      UNUSED_DICTS = %i[
        href
        ref
        proxy
        edo
        instanceAttributes
      ].freeze

      def initialize(attr_dict, name = nil)
        @name = name || attr_dict.name
        @value = nil
        @attribute_type = nil
        @options = nil
        @ifc_type_name = nil
        @ifc_type = nil

        extract_value_recursively(attr_dict)
      end

      private

      # Recursively process attribute dictionaries to find the value
      def extract_value_recursively(attr_dict)
        # Check if the current dictionary contains a value
        if attr_dict['value']
          set_attributes_from_dict(attr_dict)
          return
        end

        # Recursively process child dictionaries
        child_dicts = attr_dict.attribute_dictionaries
        return unless child_dicts

        child_dicts.each do |child_dict|
          next if UNUSED_DICTS.include?(child_dict.name.to_sym)

          extract_value_recursively(child_dict)
          break if @value # Stop further recursion once a value is found
        end
      end

      # Set attributes from the dictionary where the value is found
      def set_attributes_from_dict(attr_dict)
        @value = attr_dict['value']
        @attribute_type = attr_dict['attribute_type'] ? attr_dict['attribute_type'].to_sym : nil
        @options = attr_dict['options']

        # Determine IFC type from the current dictionary
        set_ifc_type(attr_dict['ifc_type'] || attr_dict.name)
      end

      def set_ifc_type(ifc_type_name)
        return unless IfcManager::Types.const_defined?(ifc_type_name)

        @ifc_type_name = ifc_type_name
        @ifc_type = IfcManager::Types.const_get(ifc_type_name)
      rescue NameError
        # Skip invalid constant names
      end
    end
  end
end
