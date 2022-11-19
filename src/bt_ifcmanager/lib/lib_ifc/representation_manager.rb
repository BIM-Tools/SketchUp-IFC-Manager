# frozen_string_literal: true

#  representation_manager.rb
#
#  Copyright 2021 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'ifc_mapped_item_builder'
require_relative 'ifc_product_definition_shape_builder'
require_relative 'material_and_styling'

module BimTools
  module IfcManager
    # Class that keeps track of all different shaperepresentations for
    #   the different sketchup component definitions
    class RepresentationManager
      def initialize(ifc_model)
        @ifc_model = ifc_model
        @definition_managers = {}
      end

      def get_definition_manager(definition)
        unless @definition_managers.key?(definition)
          @definition_managers[definition] = DefinitionManager.new(@ifc_model, definition)
        end
        @definition_managers[definition]
      end
    end

    # Class that keeps track of all different shaperepresentations for
    #   a sketchup component definition
    class DefinitionManager
      attr_reader :definition, :name

      def initialize(ifc_model, definition)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @definition = definition
        @name = definition.name
        @representations = {}
      end

      # Get IFC representation for a component instance
      #   creates a new one when one does not yet exist for the definition
      #   with the given transformation otherwise returns the matching one
      #
      # (?) Faces are extracted for every instance of a component, it should
      #   be possible to only do that once for a component definition
      #
      # @param [Sketchup::ComponentDefinition] definition
      # @param [Array<Sketchup::Face>] faces
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @return [BimTools::IFC2X3::IfcFacetedBrep]
      def get_representation(faces, transformation, material = nil)
        material_name = material ? material.name : ''
        representation_string = "#{transformation.to_a}_#{material_name}"
        unless @representations.key?(representation_string)
          @representations[representation_string] =
            IfcManager::ShapeRepresentation.new(@ifc_model, faces, transformation, material)
        end
        @representations[representation_string]
      end

      # Add representation to the IfcProduct, transform geometry with given transformation
      #
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @param [Sketchup::Layer] su_layer
      def create_representation(faces, transformation, su_material, su_layer)
        # Check if Mapped representation should be used
        if @ifc_model.options[:mapped_items]
          definition_representation = get_representation(faces, transformation, su_material)
          target = @ifc::IfcCartesianTransformationOperator3D.new(@ifc_model)
          target.localorigin = @ifc_model.default_location

          mapped_item = IfcMappedItemBuilder.build(@ifc_model) do |builder|
            builder.set_mappingsource(definition_representation.representationmap)
            builder.set_mappingtarget(target)
          end

          shape_representation = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
            builder.set_contextofitems(@ifc_model.representationcontext)
            builder.set_representationtype
            builder.add_item(mapped_item)
          end
        else
          brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
          shape_representation = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
            builder.set_contextofitems(@ifc_model.representationcontext)
            builder.set_representationtype
            builder.add_item(brep)
          end
          add_styling(@ifc_model, brep, su_material)
        end

        # set layer
        if @ifc_model.options[:layers]

          # check if IfcPresentationLayerAssignment exists
          unless @ifc_model.layers[su_layer.name]
            @ifc_model.layers[su_layer.name] = @ifc::IfcPresentationLayerAssignment.new(@ifc_model, su_layer)
          end

          # add self to IfcPresentationLayerAssignment
          @ifc_model.layers[su_layer.name].assigneditems.add(shape_representation)
        end

        representation = IfcProductDefinitionShapeBuilder.build(@ifc_model) do |builder|
          builder.add_representation(shape_representation)
        end
      end

      def add_styling(ifc_model, brep, su_material)
        if ifc_model.options[:colors] && su_material
          unless ifc_model.materials[su_material]
            ifc_model.materials[su_material] = MaterialAndStyling.new(ifc_model, su_material)
          end
          ifc_model.materials[su_material].add_to_styling(brep)
        end
      end
    end

    class ShapeRepresentation
      attr_reader :brep, :shaperepresentation, :representationmap

      def initialize(ifc_model, faces, transformation, su_material)
        @ifc = Settings.ifc_module
        @brep = @ifc::IfcFacetedBrep.new(ifc_model, faces, transformation)

        @shaperepresentation = IfcShapeRepresentationBuilder.build(ifc_model) do |builder|
          builder.set_contextofitems(ifc_model.representationcontext)
          builder.set_representationtype('Brep')
          builder.add_item(@brep)
        end

        @representationmap = @ifc::IfcRepresentationMap.new(ifc_model)
        @representationmap.mappingorigin = ifc_model.default_placement
        @representationmap.mappedrepresentation = @shaperepresentation

        add_styling(ifc_model, brep, su_material)
      end

      def add_styling(ifc_model, brep, su_material)
        if ifc_model.options[:colors] && su_material
          unless ifc_model.materials[su_material]
            ifc_model.materials[su_material] = MaterialAndStyling.new(ifc_model, su_material)
          end
          ifc_model.materials[su_material].add_to_styling(brep)
        end
      end
    end
  end
end
