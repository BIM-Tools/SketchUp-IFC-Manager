# frozen_string_literal: true

#  definition_manager.rb
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

require_relative 'ifc_product_definition_shape_builder'
require_relative 'definition_representation'
require_relative 'material_and_styling'
require_relative 'geometry_helpers'

module BimTools
  module IfcManager
    # Class that keeps track of all different shaperepresentations for
    #   a sketchup component definition
    class DefinitionManager
      attr_reader :definition, :name, :faces, :representations

      def initialize(ifc_model, definition)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @geometry_type = get_geometry_type(ifc_model)
        @definition = definition
        @name = definition.name
        @representations = {}
        @faces = definition.entities.select { |entity| entity.instance_of?(Sketchup::Face) }
      end

      # Get IFC representation for a component instance
      #   creates a new one when one does not yet exist for the definition
      #   with the given transformation otherwise returns the matching one
      #

      # (?) Faces are extracted for every instance of a component, it should
      #   be possible to only do that once for a component definition

      def get_geometry_type(ifc_model)
        geometry_type = ifc_model.options[:geometry]

        # Fallback to Brep when Tessellation not available in current IFC schema
        geometry_type = 'Brep' if geometry_type == 'Tessellation' && !@ifc.const_defined?(:IfcTriangulatedFaceSet)
        geometry_type
      end

      #
      # @param [Sketchup::ComponentDefinition] definition
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @return [IfcFacetedBrep]
      def get_definition_representation(transformation, su_material = nil, geometry_type = nil)
        # Check if geometry must be added
        return nil if @geometry_type == 'None' || @faces.length == 0

        geometry_type ||= @geometry_type

        representation_string = get_representation_string(transformation, su_material)
        unless @representations.key?(representation_string)
          @representations[representation_string] =
            DefinitionRepresentation.new(@ifc_model, geometry_type, @faces, su_material, transformation)
        end
        @representations[representation_string]
      end

      # Get IfcShapeRepresentation, with correct transformation
      #
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @param [Sketchup::Layer] su_layer
      #
      # @return IfcShapeRepresentation
      def get_shape_representation(transformation, su_material, su_layer = nil, geometry_type = nil)
        geometry_type ||= @geometry_type
        definition_representation = get_definition_representation(transformation, su_material, geometry_type)

        return unless definition_representation

        # Check if the geometry can be represented as an extrusion
        extrusion = determine_extrusion(geometry_type)
        geometry_type = @geometry_type if extrusion.nil?

        shape_representation = build_shape_representation(
          geometry_type,
          definition_representation.representations(extrusion)
        )

        assign_to_layer(shape_representation, su_layer) if su_layer && @ifc_model.options[:layers]

        shape_representation
      end

      def determine_extrusion(geometry_type)
        return unless geometry_type == 'SweptSolid' && @definition

        GeometryHelpers.is_extrusion?(@definition)
      end

      def build_shape_representation(representation_type, representations)
        IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
          builder.set_contextofitems(@ifc_model.representationcontext)
          builder.set_representationtype(representation_type)
          builder.set_items(representations)
        end
      end

      def get_representation_string(transformation, su_material = nil)
        "#{transformation.to_a}#{su_material}"
      end

      def assign_to_layer(shape_representation, su_layer)
        unless @ifc_model.layers[su_layer.name]
          @ifc_model.layers[su_layer.name] = @ifc::IfcPresentationLayerAssignment.new(@ifc_model, su_layer)
        end
        @ifc_model.layers[su_layer.name].assigneditems.add(shape_representation)
      end
    end
  end
end
