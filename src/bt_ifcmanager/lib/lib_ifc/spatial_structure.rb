# frozen_string_literal: true

#  spatial_structure.rb
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

module BimTools
  module IfcManager
    # The SpatialStructureHierarchy class represents the entity path to a given entity within the IFC project spatial hierarchy.
    #
    class SpatialStructureHierarchy
      # This creator class creates the SpatialStructureHierarchy object for a specific IFC entity
      #
      # @param ifc_entity [IFC2X3::IfcProduct] IFC Entity
      # @param spatial_hierarchy [Hash<IFC2X3::IfcSpatialStructureElement>] Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
      def initialize(ifc_model, spatial_structure = nil)
        @ifc_module = ifc_model.ifc_module
        @spatial_order = [
          @ifc_module::IfcProject,
          @ifc_module::IfcSite,
          @ifc_module::IfcBuilding,
          @ifc_module::IfcBuildingStorey,
          @ifc_module::IfcSpace
        ].freeze
        @ifc_model = ifc_model
        @spatial_structure = if spatial_structure
                               spatial_structure.to_a.clone
                             else
                               []
                             end
      end

      # Insert given entity into entity path after given type
      #
      # @param ifc_entity [BimTools::IFC2X3::IfcProduct]
      # @param ifc_type [BimTools::IFC2X3::IfcProduct] class
      def insert_after(ifc_entity, ifc_type)
        index = get_spatial_structure_types.rindex(ifc_type)
        index += 1
        @spatial_structure.insert(index, ifc_entity)
      end

      # Adds an IfcProduct entity to the correct place in the spatial structure.
      #
      # @param ifc_entity [Object] The IFC entity to be added.
      # @return [void]
      def add(ifc_entity)
        spatial_structure_types = get_spatial_structure_types
        case ifc_entity
        when @ifc_module::IfcProject
          # (!) Check!!!
          @spatial_structure[0] = ifc_entity
        when @ifc_module::IfcSite
          add_spatialelement(ifc_entity, spatial_structure_types, @ifc_module::IfcSite, [@ifc_module::IfcProject])
        when @ifc_module::IfcBuilding
          add_spatialelement(ifc_entity, spatial_structure_types, @ifc_module::IfcBuilding, [@ifc_module::IfcSite])
        when @ifc_module::IfcBuildingStorey
          add_spatialelement(ifc_entity, spatial_structure_types, @ifc_module::IfcBuildingStorey,
                             [@ifc_module::IfcBuilding])
        when @ifc_module::IfcSpace
          add_spatialelement(ifc_entity, spatial_structure_types, @ifc_module::IfcSpace,
                             [@ifc_module::IfcBuildingStorey, @ifc_module::IfcSite])
        when @ifc_module::IfcElementAssembly, @ifc_module::IfcCurtainWall, @ifc_module::IfcRoof

          # add to end but check for basic spatial hierarchy
          if (spatial_structure_types & [@ifc_module::IfcSpace, @ifc_module::IfcBuildingStorey,
                                         @ifc_module::IfcSite]).empty?
            add_default_spatialelement(@ifc_module::IfcBuildingStorey)
          end
          @spatial_structure << ifc_entity
        else # IfcProduct, IfcGroup

          # don't add but check for basic spatial hierarchy
          if (spatial_structure_types & [@ifc_module::IfcSpace, @ifc_module::IfcBuildingStorey,
                                         @ifc_module::IfcSite]).empty?
            add_default_spatialelement(@ifc_module::IfcBuildingStorey)
          end
        end
      end

      # Adds a spatial element to the project's spatial structure.
      #
      # @param ifc_entity [Object] The IFC entity to which the spatial element will be added.
      # @param spatial_structure_types [Array] An array of spatial structure types.
      # @param structure_type [Object] The structure type of the spatial element.
      # @param parent_structure_types [Array] An array of parent structure types.
      # @return [void]
      def add_spatialelement(ifc_entity, spatial_structure_types, structure_type, parent_structure_types)
        complex_parent_index = spatial_structure_types.rindex(structure_type)
        if complex_parent_index
          add_complex_spatialelement(ifc_entity, structure_type, complex_parent_index)
        else
          parent_structure_type = parent_structure_types.find { |type| spatial_structure_types.include?(type) }
          if parent_structure_type
            insert_after(ifc_entity, parent_structure_type)
          else
            unless parent_structure_types.empty?
              add_default_spatialelement(parent_structure_types.last)
              add_spatialelement(ifc_entity, get_spatial_structure_types, structure_type,
                                 parent_structure_types[0...-1])
            end
          end
        end
      end

      # Adds a default spatial element to the spatial structure hierarchy
      # for given class and add to entity path.
      #
      # @param entity_class [Class] The class of the entity for which to add a default spatial element.
      # @return [void]
      def add_default_spatialelement(entity_class)
        spatial_structure_types = get_spatial_structure_types
        # find parent type, if entity not present find the next one
        index = @spatial_order.rindex(entity_class) - 1
        parent_class = @spatial_order[index]
        add_default_spatialelement(parent_class) unless spatial_structure_types.include?(parent_class)
        spatial_structure_types = get_spatial_structure_types

        parent_index = spatial_structure_types.rindex(parent_class)
        parent = @spatial_structure[parent_index]

        # check if default_related_object is already set
        unless parent.default_related_object
          default_parent = entity_class.new(@ifc_model)
          default_parent.name = Types::IfcLabel.new(@ifc_model,
                                                    +'default ' << entity_class.name.split('::').last.split(/(?=[A-Z])/).drop(1).join(' ').downcase)

          # Add new ObjectPlacement without transformation
          default_parent.objectplacement = @ifc_module::IfcLocalPlacement.new(@ifc_model)
          default_parent.objectplacement.relativeplacement = @ifc_model.default_placement
          default_parent.objectplacement.placementrelto = parent.objectplacement if parent.respond_to?(:objectplacement)

          # set default related element
          parent.default_related_object = default_parent
        end
        add(parent.default_related_object)
        set_parent(parent.default_related_object)
      end

      # Adds a complex spatial element to the spatial structure.
      #
      # @param ifc_entity [Object] The IFC entity to be added.
      # @param structure_type [Symbol] The structure type of the spatial element.
      # @param complex_parent_index [Integer] The index of the complex parent in the spatial structure.
      # @return [void]
      def add_complex_spatialelement(ifc_entity, structure_type, complex_parent_index)
        @spatial_structure[complex_parent_index].compositiontype = :complex
        ifc_entity.compositiontype = :partial
        insert_after(ifc_entity, structure_type)
      end

      def to_a
        @spatial_structure
      end

      def get_spatial_structure_types
        @spatial_structure.map(&:class)
      end

      # Add entity to the model structure
      def set_parent(ifc_entity)
        index = @spatial_structure.index(ifc_entity)
        parent = if index
                   if index > 1
                     @spatial_structure[index - 1]
                   else
                     @spatial_structure[0]
                   end
                 else
                   @spatial_structure[-1]
                 end
        ifc_entity.parent = parent
        case ifc_entity
        when @ifc_module::IfcSpatialStructureElement
          ifc_entity.parent.add_related_object(ifc_entity)
        else
          case ifc_entity.parent
          when @ifc_module::IfcSpatialStructureElement
            ifc_entity.parent.add_contained_element(ifc_entity)
          when @ifc_module::IfcProject, @ifc_module::IfcProduct, @ifc_module::IfcCurtainWall, @ifc_module::IfcElementAssembly
            ifc_entity.parent.add_related_object(ifc_entity)
          end
        end
      end

      # Returns the placement parent of an element.
      #
      # If the given placement_parent is an instance of IfcSpatialStructureElement, it is returned as is.
      # Otherwise, it searches for the first object of type IfcSite in the @spatial_structure collection and returns it.
      #
      # @param placement_parent [Object] The placement parent to check.
      # @return [Object] The placement parent of the element.
      def get_placement_parent(placement_parent)
        return placement_parent if placement_parent.is_a? @ifc_module::IfcSpatialStructureElement

        @spatial_structure.find { |entity| entity.is_a? @ifc_module::IfcSite }
      end
    end
  end
end
