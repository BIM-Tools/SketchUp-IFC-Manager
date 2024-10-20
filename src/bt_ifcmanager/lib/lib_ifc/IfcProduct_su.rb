# frozen_string_literal: true

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

require_relative 'ifc_types'
require_relative 'dynamic_attributes'
require_relative 'PropertyReader'
require_relative 'material_and_styling'
require_relative 'base_quantity_builder'
require_relative 'ifc_rel_adheres_to_element_builder'

module BimTools
  module IfcProduct_su
    attr_accessor :su_object, :parent, :total_transformation, :type_product

    @su_object = nil
    @parent = nil
    @has_surface_features = nil

    # @param [BimTools::IfcManager::IfcModel] ifc_model
    # @param [nil, #definition] sketchup an empty object (default object), Sketchup::ComponentInstance or Sketchup::Group
    def initialize(ifc_model, sketchup, total_transformation)
      @total_transformation = total_transformation
      super(ifc_model, sketchup)

      @ifc_module = ifc_model.ifc_module
      @ifc_model = ifc_model

      # TODO: prevent initializing of IfcProduct for non-Sketchup objects
      return unless sketchup.respond_to?(:definition)

      @su_object = sketchup
      definition = @su_object.definition

      # When instance name is set, use that, otherwise use definition name
      # (?) set name, here? is this a duplicate?
      name = @su_object.name
      name = definition.name if name.length == 0
      @name = IfcManager::Types::IfcLabel.new(ifc_model, name)

      # Set IfcProductType
      if ifc_model.options[:types]
        if @ifc_model.product_types.key?(definition)
          @type_product = @ifc_model.product_types[definition]
          @type_product.add_typed_object(self)
        else
          type_name = self.class.name.split('::').last + 'Type'
          if @ifc_module.const_defined?(type_name)
            type_product = @ifc_module.const_get(type_name)
            @type_product = type_product.new(ifc_model, definition, self.class)
            @ifc_model.product_types[definition] = @type_product
            @type_product.add_typed_object(self)
          end
        end
      end
      @type_properties = ifc_model.options[:type_properties] && @type_product

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

      # unset ObjectType if a IfcTypeProduct is defined
      if @type_product && defined?(predefinedtype)
        @predefinedtype = nil
      end

      # TODO: dont exclude on class but on relaggregates
      add_material_association if ifc_model.options[:materials] &&
                                  (is_a? @ifc_module::IfcElement) &&
                                  !(is_a? @ifc_module::IfcFeatureElementSubtraction) &&
                                  !(is_a? @ifc_module::IfcVirtualElement) &&
                                  !(is_a? @ifc_module::IfcSpatialStructureElement) &&
                                  !(is_a? @ifc_module::IfcRoof) &&
                                  !(is_a? @ifc_module::IfcElementAssembly) &&
                                  !(is_a? @ifc_module::IfcCurtainWall) &&
                                  !(defined?(@ifc_module::IfcSpatialZone) && is_a?(@ifc_module::IfcSpatialZone))

      # collect dynamic component attributes if export option is set
      BimTools::DynamicAttributes.get_dynamic_attributes(ifc_model, self) if ifc_model.options[:dynamic_attributes]

      return unless ifc_model.options[:base_quantities]

      add_base_quantities
    end

    # Adds a surface feature to the IFC element.
    #
    # @param surface_feature [Object] The surface feature to be added.
    # @return [void]
    def add_surface_feature(surface_feature)
      create_ifc_rel_adheres_to_element unless @has_surface_features
      @has_surface_features.add_related_surface_feature(surface_feature)
    end

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end

    private

    # Creates an IfcRelAdheresToElement relationship for the IFC element.
    #
    # @return [void]
    def create_ifc_rel_adheres_to_element
      @has_surface_features = BimTools::IfcManager::IfcRelAdheresToElementBuilder.build(@ifc_model) do |builder|
        builder.set_relating_element(self)
      end
    end

    # set material if sketchup @su_object has a material
    # Material added to Product and not to TypeProduct because a Sketchup ComponentDefinition can have a different material for every Instance
    def add_material_association
      su_material = @su_object.material
      unless @ifc_model.materials.include?(su_material)
        @ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(@ifc_model, su_material)
      end

      @ifc_model.materials[su_material].add_to_material(self)
    end

    def add_base_quantities
      unless is_a?(@ifc_module::IfcColumn) || is_a?(@ifc_module::IfcBeam) || is_a?(@ifc_module::IfcSlab) || is_a?(@ifc_module::IfcWall)
        return
      end

      BimTools::IfcManager::BaseQuantityBuilder.build(@ifc_model) do |builder|
        builder.add_base_quantities(self, @su_object)
      end
    end
  end
end
