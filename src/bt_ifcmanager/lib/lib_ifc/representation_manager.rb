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

        # Check if geometry must be added
        if @ifc_model.options[:geometry] == 'None'
          return
        end

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
          mesh = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
          shape_representation = IfcShapeRepresentationBuilder.build(@ifc_model) do |builder|
            builder.set_contextofitems(@ifc_model.representationcontext)
            builder.set_representationtype
            builder.add_item(mesh)
          end
        
          if @ifc_model.options[:colors]
            styled_item = @ifc::IfcStyledItem.new(@ifc_model, mesh)
            styles = get_surface_styles(@ifc_model, su_material)
            styled_item.styles = styles
          end
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

      def get_surface_styles(ifc_model, parent_material, front_material=nil, back_material=nil)
        unless front_material
          front_material = parent_material
        end
        unless back_material
          back_material = front_material
        end
        if front_material == back_material
          return Types::Set.new([get_styling(ifc_model, front_material, :both)])
        end
        return Types::Set.new([get_styling(ifc_model, front_material, :positive), get_styling(ifc_model, back_material, :negative)])
      end
      
      def get_styling(ifc_model, su_material, side=:both)
        unless ifc_model.materials[su_material]
          ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(ifc_model, su_material)
        end
        styling = ifc_model.materials[su_material].get_styling(side)
        return styling
      end
    end

    class ShapeRepresentation
      attr_reader :brep, :shaperepresentation, :representationmap

      def initialize(ifc_model, faces, transformation, su_material)
        @ifc = Settings.ifc_module
        geometry_type = ifc_model.options[:geometry]

        # Fallback to Brep when Tessellation not available in current IFC schema
        if geometry_type == 'Tessellation' && !@ifc.const_defined?(:IfcTriangulatedFaceSet)
          geometry_type = 'Brep'
        end

        items = create_meshes(ifc_model, faces, transformation, su_material, geometry_type)
        @shaperepresentation = IfcShapeRepresentationBuilder.build(ifc_model) do |builder|
          builder.set_contextofitems(ifc_model.representationcontext)
          builder.set_representationtype(geometry_type)
          builder.set_items(items)
        end  
        @representationmap = @ifc::IfcRepresentationMap.new(ifc_model)
        @representationmap.mappingorigin = ifc_model.default_placement
        @representationmap.mappedrepresentation = @shaperepresentation        
      end

      def create_meshes(ifc_model, faces, transformation, su_material=nil, geometry_type=nil)
        # if su_material
          faces_by_material = faces.group_by{|face|[face.material,face.back_material]}
          if faces_by_material.length>0
            return faces_by_material.map do |face_materials, face_group|
              create_mesh(ifc_model, face_group, transformation, su_material, geometry_type, face_materials)
            end
          end
        # end
        return [create_mesh(ifc_model, faces, transformation, su_material, geometry_type)]
      end
      
      def create_mesh(ifc_model, faces, transformation, su_material=nil, geometry_type=nil, face_materials=nil)
        mesh = nil
        front_material = face_materials[0] if face_materials
        back_material = face_materials[1] if face_materials
        if geometry_type == 'Tessellation'
          mesh = @ifc::IfcTriangulatedFaceSet.new(ifc_model, faces, transformation, su_material, front_material, back_material)
        else # 'Brep'
          mesh = @ifc::IfcFacetedBrep.new(ifc_model, faces, transformation)
        end
        
        if ifc_model.options[:colors]
          styled_item = @ifc::IfcStyledItem.new(ifc_model, mesh)
          styled_item.styles = get_surface_styles(ifc_model, su_material, front_material, back_material)
        end

        return mesh
      end

      def get_surface_styles(ifc_model, parent_material=nil, front_material=nil, back_material=nil)
        if !front_material && !back_material
          return Types::Set.new([get_styling(ifc_model, parent_material, :both)])
        end
        if front_material && back_material
          return Types::Set.new([get_styling(ifc_model, front_material, :positive), get_styling(ifc_model, back_material, :negative)])
        end
        if front_material && parent_material
          return Types::Set.new([get_styling(ifc_model, front_material, :positive), get_styling(ifc_model, parent_material, :negative)])
        end
        if back_material && parent_material
          return Types::Set.new([get_styling(ifc_model, parent_material, :positive), get_styling(ifc_model, back_material, :negative)])
        end
        if front_material && front_material == back_material
          return Types::Set.new([get_styling(ifc_model, front_material, :both)])
        end
        return Types::Set.new([get_styling(ifc_model, parent_material, :both)])
      end
      
      def get_styling(ifc_model, su_material, side=:both)
        unless ifc_model.materials[su_material]
          ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(ifc_model, su_material)
        end
        return ifc_model.materials[su_material].get_styling(side)
      end
    end
  end
end
