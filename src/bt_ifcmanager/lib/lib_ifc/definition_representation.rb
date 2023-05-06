# frozen_string_literal: true

#  definition_representation.rb
#
#  Copyright 2023 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'ifc_faceted_brep_builder'
require_relative 'material_and_styling'

module BimTools
  module IfcManager
    # Class that manages a specific representation for
    #   a sketchup component definition
    class DefinitionRepresentation
      attr_reader :shape_representation_builder, :faceted_brep, :faceted_breps

      def initialize(ifc_model, faces, su_material, transformation)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_shape_representation_builder = nil
        @mapped_representation = nil
        @faceted_brep = get_faceted_brep(faces, su_material, transformation)
        @faceted_breps = Types::Set.new([@faceted_brep])
      end

      def get_mapped_representation
        @mapped_representation ||= IfcMappedItemBuilder.build(@ifc_model) do |builder|
          builder.set_mappingsource(get_mapping_source)
        end
      end

      def get_mapping_source
        shaperepresentation = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
          # builder.add_definition_manager(self)
          builder.set_contextofitems(@ifc_model.representationcontext)
          builder.set_representationtype('Brep')
          builder.set_items(@faceted_breps)
        end

        representationmap = @ifc::IfcRepresentationMap.new(@ifc_model)
        representationmap.mappingorigin = @ifc_model.default_placement
        representationmap.mappedrepresentation = shaperepresentation
        representationmap
      end

      # def get_shape_representation_builder
      #   if @ifc_shape_representation_builder
      #     @ifc_shape_representation_builder
      #   else
      #     # brep = @ifc::IfcFacetedBrep.new(@ifc_model, @faces, transformation)

      #     ifc_shape_representation_builder = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
      #       builder.add_definition_manager(self)
      #       builder.set_contextofitems(@ifc_model.representationcontext)
      #       builder.set_representationtype('Brep')
      #       # builder.add_item(brep)
      #       # builder.add_styling(brep, su_material)
      #     end

      #     @shaperepresentation = ifc_shape_representation_builder.ifc_shape_representation

      #     @representationmap = @ifc::IfcRepresentationMap.new(@ifc_model)
      #     @representationmap.mappingorigin = @ifc_model.default_placement
      #     @representationmap.mappedrepresentation = @shaperepresentation

      #     @shape_representation_builder = ifc_shape_representation_builder
      #     @ifc_shape_representation_builder = ifc_shape_representation_builder
      #     ifc_shape_representation_builder
      #   end
      # end

      # Set the definition-representations OWN representation using it's faces
      def get_faceted_brep(faces, _su_material, transformation)
        IfcFacetedBrepBuilder.build(@ifc_model) do |builder|
          builder.set_transformation(transformation)
          builder.set_outer(faces)
          # builder.set_styling(su_material)
        end
      end

      # # Set the definition-representations OWN representation using it's faces
      # def set_faceted_brep(faces, _su_material, transformation)
      #   @faceted_brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
      #   # ifc_shape_representation_builder = get_shape_representation_builder
      #   # ifc_shape_representation_builder.add_item(@faceted_brep)
      #   # add_styling(@faceted_brep, su_material)
      # end

      def add_faceted_brep(brep)
        @faceted_breps.add(brep)
      end
    end
  end
end
