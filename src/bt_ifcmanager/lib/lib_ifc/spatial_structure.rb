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
        @ifc_model = ifc_model
        @spatial_structure = spatial_structure.to_a.clone if spatial_structure
        @spatial_structure ||= []
      end

      # Insert given entity into entity path after given entity
      #
      # @param ifc_entity [IfcProduct]
      # @param parent_entity [IfcProduct]
      def insert_after(ifc_entity, parent_entity)
        index = @spatial_structure.index(parent_entity)
        @spatial_structure.insert(index + 1, ifc_entity)
      end

      # Adds an IfcProduct entity to the correct place in the spatial structure.
      #
      # @param ifc_entity [Object] The IFC entity to be added.
      # @return [void]
      def add(ifc_entity)
        return if ifc_entity.is_a?(@ifc_module::IfcGroup)

        if ifc_entity.is_a?(@ifc_module::IfcProject)
          @spatial_structure[0] = ifc_entity
          return
        end
        add_recursive(ifc_entity.class, ifc_entity)
      end

      def to_a
        @spatial_structure
      end

      private

      # Adds an IFC entity to the spatial structure recursively.
      #
      # This method attempts to add an IFC entity to the spatial structure, ensuring
      # that it is placed under an appropriate parent entity. If no suitable parent
      # is found, it creates a new parent entity of the preferred type.
      #
      # @param [Class] ifc_class The class of the IFC entity to be added.
      # @param [Object, nil] ifc_entity The IFC entity to be added. If nil, a default
      #   entity of the specified class will be created.
      # @return [Object] The IFC entity that was added to the spatial structure.
      def add_recursive(ifc_class, ifc_entity = nil)
        parent_structure_types = if ifc_class < @ifc_module::IfcSpatialStructureElement
                                   possible_spatial_parent_types(ifc_class)
                                 elsif @ifc_module.const_defined?(:IfcFacilityPart)
                                   [@ifc_module::IfcBuildingStorey, @ifc_module::IfcFacilityPart, @ifc_module::IfcSite,
                                    @ifc_module::IfcSpace]
                                 else
                                   [@ifc_module::IfcBuildingStorey, @ifc_module::IfcSite, @ifc_module::IfcSpace]
                                 end

        # If an entity of class ifc_class is already in the spatial structure, set that as parent
        parent = @spatial_structure.reverse.find do |entity|
          entity.is_a?(ifc_class)
        end

        # If the entity is a spatial structure element, set the composition type to a valid value
        if ifc_entity && ifc_entity.is_a?(@ifc_module::IfcSpatialStructureElement)
          if parent && parent.is_a?(@ifc_module::IfcSpatialStructureElement)
            parent.compositiontype = :complex
            ifc_entity.compositiontype = :partial
          elsif ifc_entity.compositiontype == :complex || ifc_entity.compositiontype == :partial
            ifc_entity.compositiontype = :element
          end
        end

        # # Add a default storey in case the parent is a building and the entity is not a spatial structure element
        # if ifc_entity && !ifc_entity.is_a?(@ifc_module::IfcSpatialStructureElement) && @spatial_structure.any? do |entity|
        #      entity.is_a?(@ifc_module::IfcBuilding)
        #    end
        #   parent_structure_types = [@ifc_module::IfcBuildingStorey]
        # end

        # If no parent of the given class is found, try to find a parent from one of the preferred parent types
        parent ||= @spatial_structure.reverse.find do |entity|
          parent_structure_types.any? { |parent_structure_type| entity.is_a?(parent_structure_type) }
        end

        # If no parent is found, create a new parent of the first preferred parent type
        parent = add_recursive(parent_structure_types.first) if parent.nil? && !parent_structure_types.empty?

        raise "No valid parent found for #{ifc_class}" if parent.nil?

        if [@ifc_module::IfcElementAssembly, @ifc_module::IfcCurtainWall, @ifc_module::IfcRoof].include?(ifc_class)
          @spatial_structure << ifc_entity
        end

        parent ||= @spatial_structure.last unless ifc_entity.is_a?(@ifc_module::IfcSpatialStructureElement)

        ifc_entity ||= get_default_child_of_type(parent, ifc_class)
        insert_after(ifc_entity, parent) if ifc_entity.is_a?(@ifc_module::IfcSpatialStructureElement)
        set_parent(ifc_entity, parent) unless ifc_entity.is_a?(@ifc_module::IfcProject)

        ifc_entity
      end

      def possible_spatial_parent_types(ifc_class)
        if ifc_class == @ifc_module::IfcSite
          [@ifc_module::IfcProject]
        elsif ifc_class == @ifc_module::IfcBuilding
          [@ifc_module::IfcSite]
        elsif ifc_class == @ifc_module::IfcBuildingStorey
          [@ifc_module::IfcBuilding, @ifc_module::IfcSite]
        elsif ifc_class == @ifc_module::IfcSpace
          if @ifc_module.const_defined?(:IfcFacility)
            [@ifc_module::IfcBuildingStorey, @ifc_module::IfcFacility, @ifc_module::IfcSite]
          else
            [@ifc_module::IfcBuildingStorey, @ifc_module::IfcSite]
          end
        elsif @ifc_module.const_defined?(:IfcBridge) && ifc_class == @ifc_module::IfcBridge
          [@ifc_module::IfcSite]
        elsif @ifc_module.const_defined?(:IfcBridgePart) && ifc_class == @ifc_module::IfcBridgePart
          [@ifc_module::IfcBridge]
        elsif @ifc_module.const_defined?(:IfcRailway) && ifc_class == @ifc_module::IfcRailway
          [@ifc_module::IfcSite]
        elsif @ifc_module.const_defined?(:IfcRailwayPart) && ifc_class == @ifc_module::IfcRailwayPart
          [@ifc_module::IfcRailway]
        elsif @ifc_module.const_defined?(:IfcRoad) && ifc_class == @ifc_module::IfcRoad
          [@ifc_module::IfcSite]
        elsif @ifc_module.const_defined?(:IfcRoadPart) && ifc_class == @ifc_module::IfcRoadPart
          [@ifc_module::IfcRoad]
        elsif @ifc_module.const_defined?(:IfcMarineFacility) && ifc_class == @ifc_module::IfcMarineFacility
          [@ifc_module::IfcSite]
        elsif @ifc_module.const_defined?(:IfcMarineFacilityPart) && ifc_class == @ifc_module::IfcMarineFacilityPart
          [@ifc_module::IfcMarineFacility]
        elsif @ifc_module.const_defined?(:IfcFacility) && ifc_class == @ifc_module::IfcFacility
          [@ifc_module::IfcSite]
        elsif @ifc_module.const_defined?(:IfcFacilityPart) && ifc_class == @ifc_module::IfcFacilityPart
          [@ifc_module::IfcFacility]
        else
          [@ifc_module::IfcBuilding, @ifc_module::IfcSite, @ifc_module::IfcBuildingStorey]
        end
      end

      def get_default_child_of_type(parent, entity_class)
        # Check if the parent already has a default child of the given type
        existing_child = parent.default_decomposing_object_of_type(entity_class)
        return existing_child if existing_child

        # Create a new default child entity
        default_child = entity_class.new(@ifc_model, nil, nil)
        name = "default #{entity_class.name.split('::').last.split(/(?=[A-Z])/).drop(1).join(' ').downcase}"
        default_child.name = Types::IfcLabel.new(@ifc_model, name)
        parent.add_default_decomposing_object(default_child)

        # Add a new ObjectPlacement without transformation
        default_child.objectplacement = @ifc_module::IfcLocalPlacement.new(@ifc_model)
        default_child.objectplacement.relativeplacement = @ifc_model.default_placement

        # Link placement to the parent, if applicable
        unless parent.is_a?(@ifc_module::IfcProject)
          default_child.objectplacement.placementrelto = parent.objectplacement
        end

        default_child
      end

      # Add entity to the model structure
      def set_parent(ifc_entity, parent)
        index = @spatial_structure.index(ifc_entity)
        # parent = if index
        #            if index > 1
        #              @spatial_structure[index - 1]
        #            else
        #              @spatial_structure[0]
        #            end
        #          else
        #            @spatial_structure[-1]
        #          end
        ifc_entity.parent = parent

        # IfcSurfaceFeature is not part of the normal spatial structure from IFC4X3 onwards
        return if defined?(@ifc_module::IfcSurfaceFeature) &&
                  defined?(@ifc_module::IfcRelAdheresToElement) &&
                  ifc_entity.is_a?(@ifc_module::IfcSurfaceFeature)

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
    end
  end
end
