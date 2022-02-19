#  IfcProduct_su.rb
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

# load types
require_relative 'IfcBoolean'
require_relative 'IfcDate'
require_relative 'IfcLabel'
require_relative 'IfcIdentifier'
require_relative 'IfcReal'
require_relative 'IfcInteger'
require_relative 'IfcText'

require_relative 'dynamic_attributes'
require_relative 'PropertyReader'
require_relative 'propertyset'
require_relative 'material_and_styling'

module BimTools
  module IfcProduct_su
    attr_accessor :su_object, :parent, :total_transformation, :type_product

    extend BimTools::IfcManager::PropertyDictionary

    @su_object = nil
    @parent = nil

    # @param ifc_model [BimTools::IfcManager::IfcModel]
    # @param sketchup [nil, #definition] an empty object (default object), Sketchup::ComponentInstance or Sketchup::Group
    def initialize(ifc_model, sketchup)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module
      if sketchup.respond_to?(:definition)
        ifc_version = BimTools::IfcManager::Settings.ifc_version
        @ifc_model = ifc_model
        @su_object = sketchup
        definition = @su_object.definition

        # When instance name is set, use that, otherwise use definition name
        # (?) set name, here? is this a duplicate?
        name = @su_object.name
        name = definition.name if name.length == 0
        @name = BimTools::IfcManager::IfcLabel.new(ifc_model, name)

        # Set IfcProductType
        if ifc_model.options[:types]
          if @ifc_model.product_types.key?(definition)
            @type_product = @ifc_model.product_types[definition]
            @type_product.add_typed_object(self)
          else
            type_name = self.class.name.split('::').last + 'Type'
            if @ifc.const_defined?(type_name)
              type_product = @ifc.const_get(type_name)
              @type_product = type_product.new(ifc_model, definition, self.class)
              @ifc_model.product_types[definition] = @type_product
              @type_product.add_typed_object(self)
            end
          end
        end
        @type_properties = ifc_model.options[:type_properties] && @type_product

        # (?) set "tag" to component instance name?
        # tag definition: The tag (or label) identifier at the particular instance of a product, e.g. the serial number, or the position number. It is the identifier at the occurrence level.

        # get attributes from su object and add them to IfcProduct
        if dicts = definition.attribute_dictionaries
          dict_reader = BimTools::IfcManager::IfcDictionaryReader.new(ifc_model, self, dicts)
          dict_reader.set_attributes

          unless @type_properties
            dict_reader.add_propertysets
            dict_reader.add_sketchup_definition_properties(ifc_model, self, @su_object.definition)
            dict_reader.add_classifications
          end
          dict_reader.add_sketchup_instance_properties(ifc_model, self, @su_object)
        end

        # set material if sketchup @su_object has a material
        # Material added to Product and not to TypeProduct because a Sketchup ComponentDefinition can have a different material for every Instance
        if ifc_model.options[:materials] && !((is_a? @ifc::IfcFeatureElementSubtraction) || (is_a? @ifc::IfcVirtualElement) || (is_a? @ifc::IfcSpatialStructureElement))
          material_name = if @su_object.material
                            @su_object.material.display_name
                          else
                            'Default'
                          end

          # create materialassociation
          su_material = @su_object.material
          unless ifc_model.materials[su_material]
            ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(ifc_model, su_material)
          end

          # add product to materialassociation
          ifc_model.materials[su_material].add_to_material(self)
        end

        # collect dynamic component attributes if export option is set
        BimTools::DynamicAttributes.get_dynamic_attributes(ifc_model, self) if ifc_model.options[:dynamic_attributes]

      end
    end

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end
end
