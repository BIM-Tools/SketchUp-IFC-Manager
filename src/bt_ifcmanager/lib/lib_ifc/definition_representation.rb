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
    #   a sketchup component definition including material and transformation
    class DefinitionRepresentation
      attr_reader :shape_representation_builder, :meshes

      def initialize(ifc_model, geometry_type, faces, su_material, transformation)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @geometry_type = geometry_type
        @ifc_shape_representation_builder = nil
        @mapped_representation = nil
        @representation = nil
        @double_sided_faces = @ifc_model.options[:double_sided_faces]
        @meshes = create_meshes(ifc_model, faces, transformation, su_material)
      end

      def get_mapped_representation
        @mapped_representation ||= IfcMappedItemBuilder.build(@ifc_model) do |builder|
          builder.set_mappingsource(get_mapping_source)
        end
      end

      def get_mapping_source
        shaperepresentation = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
          builder.set_contextofitems(@ifc_model.representationcontext)
          builder.set_representationtype(@geometry_type)
          builder.set_items(@meshes)
        end

        representationmap = @ifc::IfcRepresentationMap.new(@ifc_model)
        representationmap.mappingorigin = @ifc_model.default_placement
        representationmap.mappedrepresentation = shaperepresentation
        representationmap
      end

      # Set the definition-representations OWN representation using it's faces
      def create_meshes(ifc_model, faces, transformation, su_material = nil)
        # if su_material
        faces_by_material = faces.group_by { |face| [face.material, face.back_material] }
        if faces_by_material.length > 0
          return faces_by_material.map do |face_materials, face_group|
            create_mesh(ifc_model, face_group, transformation, su_material, face_materials)
          end
        end
        # end
        [create_mesh(ifc_model, faces, transformation, su_material)]
      end

      def create_mesh(ifc_model, faces, transformation, su_material = nil, face_materials = nil)
        front_material = face_materials[0] if face_materials
        back_material = face_materials[1] if face_materials
        mesh = if @geometry_type == 'Tessellation'
                 @ifc::IfcTriangulatedFaceSet.new(
                   ifc_model,
                   faces,
                   transformation,
                   su_material,
                   front_material,
                   back_material,
                   @double_sided_faces
                 )
               else
                 IfcFacetedBrepBuilder.build(ifc_model) do |builder|
                   builder.set_transformation(transformation)
                   builder.set_outer(faces)
                   # builder.set_styling(su_material)
                 end
               end

        if ifc_model.options[:colors]
          styled_item = @ifc::IfcStyledItem.new(ifc_model, mesh)
          styled_item.styles = get_surface_styles(ifc_model, su_material, front_material, back_material)
        end

        mesh
      end

      def get_surface_styles(ifc_model, parent_material = nil, front_material = nil, back_material = nil)
        if Settings.ifc_version_compact == 'IFC2X3' || @double_sided_faces == false
          return Types::Set.new([ifc_model.get_styling(front_material, :both)]) if front_material

          Types::Set.new([ifc_model.get_styling(parent_material, :both)])
        else
          return Types::Set.new([ifc_model.get_styling(parent_material, :both)]) if !front_material && !back_material
          if front_material && front_material == back_material
            return Types::Set.new([ifc_model.get_styling(front_material, :both)])
          end

          if front_material && back_material
            return Types::Set.new([ifc_model.get_styling(front_material, :positive),
                                   ifc_model.get_styling(back_material, :negative)])
          end
          if front_material && parent_material
            return Types::Set.new([ifc_model.get_styling(front_material, :positive),
                                   ifc_model.get_styling(parent_material, :negative)])
          end
          if back_material && parent_material
            return Types::Set.new([ifc_model.get_styling(parent_material, :positive),
                                   ifc_model.get_styling(back_material, :negative)])
          end
          return Types::Set.new([ifc_model.get_styling(front_material, :both)]) if front_material

          Types::Set.new([ifc_model.get_styling(parent_material, :both)])
        end
      end

      def add_meshes(meshes)
        @meshes += meshes
      end
    end
  end
end
