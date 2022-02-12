#  IfcTypeProduct_su.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'set'
require_relative 'list'
require_relative 'IfcDate'
require_relative 'IfcGloballyUniqueId'
require_relative 'IfcLabel'

module BimTools
  module IfcTypeProduct_su
    attr_accessor :su_object

    # @param ifc_model [BimTools::IfcManager::IfcModel]
    # @param definition [Sketchup::ComponentDefinition]
    def initialize(ifc_model, definition)
      super(ifc_model, definition)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @definition = definition
      ifc_version = BimTools::IfcManager::Settings.ifc_version
      @type_properties = ifc_model.options[:type_properties]
      @propertysets = BimTools::IfcManager::Ifc_Set.new

      @rel_defines_by_type = @ifc::IfcRelDefinesByType.new(@ifc_model)
      @rel_defines_by_type.relatingtype = self
      @rel_defines_by_type.relatedobjects = BimTools::IfcManager::Ifc_Set.new

      @name = BimTools::IfcManager::IfcLabel.new(ifc_model, definition.name)
      @globalid = BimTools::IfcManager::IfcGloballyUniqueId.new(definition)

      # get attributes from su object and add them to IfcTypeProduct
      if dicts = definition.attribute_dictionaries
        dict_reader = BimTools::IfcManager::IfcDictionaryReader.new(ifc_model, self, dicts)
        dict_reader.set_attributes
        if @type_properties
          propertysets = dict_reader.get_propertysets
          @haspropertysets = BimTools::IfcManager::Ifc_Set.new(propertysets) if propertysets.length > 0
          dict_reader.add_sketchup_definition_properties(ifc_model, self, definition, @type_properties)
          dict_reader.add_classifications
        end
      end

      # if ifc_model.options[:attributes]
      #   ifc_model.options[:attributes].each do |attr_dict_name|
      #     collect_psets(ifc_model, @definition.attribute_dictionary(attr_dict_name))
      #   end
      # elsif @definition.attribute_dictionaries
      #   @definition.attribute_dictionaries.each do |attr_dict|
      #     collect_psets(ifc_model, attr_dict)
      #   end
      # end

      # Set PredefinedType to default value when not set
      @predefinedtype = :notdefined if defined?(predefinedtype) && @predefinedtype.nil?
    end

    # @param ifc_entity
    def add_typed_object(ifc_entity)
      @rel_defines_by_type.relatedobjects.add(ifc_entity)
    end
  end
end
