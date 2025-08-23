# frozen_string_literal: true

#  common_object_attributes.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'entity_dictionary_reader'
require_relative 'ifc_rel_defines_by_properties_builder'

module BimTools
  module CommonObjectAttributes
    # @param [IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentInstance] su_instance
    def add_instance_data(ifc_model, su_instance, type_product = false)
      su_definition = su_instance.definition
      dictionaries = su_definition.attribute_dictionaries
      type_properties = ifc_model.options[:type_properties] && type_product

      return unless dictionaries

      dict_reader = IfcManager::EntityDictionaryReader.new(ifc_model, self, dictionaries)
      dict_reader.set_attributes

      # Add property sets and/or quantities as appropriate
      sets = dict_reader.get_propertysets(
        include_properties: !type_properties,
        include_quantities: true
      )

      sets.each do |pset|
        IfcManager::IfcRelDefinesByPropertiesBuilder.build(ifc_model) do |builder|
          builder.set_relatingpropertydefinition(pset)
          builder.add_related_object(self)
        end
      end
      unless type_properties
        dict_reader.add_sketchup_definition_properties(ifc_model, self, su_definition)
        dict_reader.add_classifications
      end
      dict_reader.add_sketchup_instance_properties(ifc_model, self, su_instance)
    end

    # @param [IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentDefinition] su_definition
    def add_type_data(ifc_model, su_definition, instance_class)
      dictionaries = su_definition.attribute_dictionaries
      type_properties = ifc_model.options[:type_properties]

      return unless dictionaries

      dict_reader = IfcManager::EntityDictionaryReader.new(ifc_model, self, dictionaries, instance_class)
      dict_reader.set_attributes

      if type_properties
        propertysets = dict_reader.get_propertysets(
          include_properties: true,
          include_quantities: false
        )
        @haspropertysets = IfcManager::Types::Set.new(propertysets) if propertysets.length > 0
        dict_reader.add_sketchup_definition_properties(ifc_model, self, su_definition, type_properties)
        dict_reader.add_classifications
      end
    end
  end
end
