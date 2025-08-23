# frozen_string_literal: true

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

require_relative 'IfcGloballyUniqueId'
require_relative 'ifc_types'
require_relative 'ifcx/ifcx_common'

module BimTools
  module IfcTypeProduct_su
    include BimTools::CommonObjectAttributes

    attr_accessor :su_object

    # @param [BimTools::IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentDefinition] su_definition
    def initialize(ifc_model, su_definition, instance_class = nil)
      super(ifc_model, su_definition)
      @ifc_module = ifc_model.ifc_module

      persistent_id = su_definition.persistent_id.to_s

      @rel_defines_by_type = @ifc_module::IfcRelDefinesByType.new(@ifc_model)
      @rel_defines_by_type.relatingtype = self
      # if @rel_defines_by_type.respond_to?(:relatedobjects)
      @rel_defines_by_type.relatedobjects = IfcManager::Types::Set.new
      # else
      #   puts 'ERROR: @rel_defines_by_type does not respond to relatedobjects'
      # end
      @rel_defines_by_type.globalid = IfcManager::IfcGloballyUniqueId.new(ifc_model,
                                                                          "IfcRelDefinesByType.#{persistent_id}")

      @name = IfcManager::Types::IfcLabel.new(ifc_model, su_definition.name)
      @globalid = IfcManager::IfcGloballyUniqueId.new(ifc_model, "IfcTypeProduct.#{persistent_id}")

      # Set "tag" to component persistent_id like the other BIM Authoring Tools like Revit, Archicad and Tekla do
      @tag = IfcManager::Types::IfcLabel.new(ifc_model, persistent_id)

      # get attributes from su object and add them to IfcTypeProduct
      add_type_data(ifc_model, su_definition, instance_class)

      # Set PredefinedType to default value when not set
      @predefinedtype = :notdefined if defined?(predefinedtype) && @predefinedtype.nil?

      # Set AssemblyPlace to default value when not set, for IfcFurnitureType
      @assemblyplace = :notdefined if defined?(assemblyplace) && @assemblyplace.nil?
    end

    # @param ifc_entity
    def add_typed_object(ifc_entity)
      # if @rel_defines_by_type.respond_to?(:relatedobjects)
      @rel_defines_by_type.relatedobjects.add(ifc_entity)
      # else
      #   # puts 'ERROR: @rel_defines_by_type does not respond to relatedobjects1'
      #   if ifc_entity.respond_to?(:istypedby)
      #     puts '@rel_defines_by_type added to ifc_entity istypedby'
      #     ifc_entity.istypedby = IfcManager::Types::Set.new([@rel_defines_by_type])
      #   else
      #     puts 'ERROR: @rel_defines_by_type does not respond to istypedby'
      #   end
      # end
    end

    def ifcx
      result = []

      # Export every property from every property set in @haspropertysets as a separate object
      if defined?(@haspropertysets) && @haspropertysets && @haspropertysets.respond_to?(:each)
        @haspropertysets.each do |pset|
          # Get the properties array (hasproperties or quantities)
          properties = if pset.respond_to?(:hasproperties)
                         pset.hasproperties
                       elsif pset.respond_to?(:quantities)
                         pset.quantities
                       else
                         []
                       end
          properties.each do |property|
            begin
              result << {
                path: @globalid.ifcx,
                attributes: {
                  "bsi::ifc::prop::#{property.name.value}": property_to_ifcx(property)
                }
              }
            rescue StandardError
              # puts "  Error processing property: #{e.message}"
            end
          end
        end
      end

      type_attributes = self.class.attributes.each_with_object([]) do |attribute_name, arr|
        next if BimTools::IfcXCommon::EXCLUDED_ATTRIBUTES.include?(attribute_name)

        attribute_method = attribute_name.downcase
        value = begin
          send(attribute_method.to_s)
        rescue StandardError
          nil
        end

        arr << {
          path: globalid.ifcx,
          attributes: {
            "bsi::ifc::prop::#{attribute_name}" => value.respond_to?(:value) ? value.value : value
          }
        }
      end

      [result, type_attributes].flatten
    end
  end
end
