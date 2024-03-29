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
        @ifc = Settings.ifc_module
        @spatial_order = [
          @ifc::IfcProject,
          @ifc::IfcSite,
          @ifc::IfcBuilding,
          @ifc::IfcBuildingStorey,
          @ifc::IfcSpace
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

      def add(ifc_entity)
        spatial_structure_types = get_spatial_structure_types
        case ifc_entity
        when @ifc::IfcProject
          # (!) Check!!!
          @spatial_structure[0] = ifc_entity
        when @ifc::IfcSite
          if spatial_structure_types.include? @ifc::IfcSite
            # Add as partial @ifc::IfcSite
            # @todo fix option to use partial sites
            # parent_site = @spatial_structure[get_spatial_structure_types().rindex(@ifc::IfcSite)]
            # path = ["IFC 2x3", "@ifc::IfcSite", "CompositionType", "IfcElementCompositionEnum"]
            # if parent_site.su_object.definition.get_classification_value(path) == "complex" && ifc_entity.su_object.definition.get_classification_value(path) == "partial"
            #   insert_after(ifc_entity,@ifc::IfcSite)
            # else
            #   @spatial_structure[get_spatial_structure_types().rindex(@ifc::IfcSite)] = ifc_entity
            # end

            @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcSite)] = ifc_entity
          elsif spatial_structure_types.include? @ifc::IfcProject
            insert_after(ifc_entity, @ifc::IfcProject)
          end
        when @ifc::IfcBuilding
          if spatial_structure_types.include? @ifc::IfcBuilding
            # Add as partial IfcBuilding
            # insert_after(ifc_entity,@ifc::IfcBuilding)
            @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcBuilding)] = ifc_entity
          elsif spatial_structure_types.include? @ifc::IfcSite
            insert_after(ifc_entity, @ifc::IfcSite)
          else
            # Create default Site and add there
            add_default_spatialelement(@ifc::IfcSite)
            insert_after(ifc_entity, @ifc::IfcSite)
          end
        when @ifc::IfcBuildingStorey
          if spatial_structure_types.include? @ifc::IfcBuildingStorey
            # Add as partial IfcBuildingStorey
            # insert_after(ifc_entity,@ifc::IfcBuildingStorey)
            @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcBuildingStorey)] = ifc_entity
          elsif spatial_structure_types.include? @ifc::IfcBuilding
            insert_after(ifc_entity, @ifc::IfcBuilding)
          else
            # Create default IfcBuilding and add there, and check for site
            add_default_spatialelement(@ifc::IfcBuilding)
            insert_after(ifc_entity, @ifc::IfcBuilding)
          end
        when @ifc::IfcSpace
          if spatial_structure_types.include? @ifc::IfcSpace
            # Add as partial IfcBuildingStorey
            # insert_after(ifc_entity,@ifc::IfcSpace)
            @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcSpace)] = ifc_entity
          elsif spatial_structure_types.include? @ifc::IfcBuildingStorey
            insert_after(ifc_entity, @ifc::IfcBuildingStorey)
            # @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcBuildingStorey)] = ifc_entity
          elsif spatial_structure_types.include? @ifc::IfcSite
            # Add as outside space
            # insert_after(ifc_entity,@ifc::IfcSite)
            @spatial_structure[get_spatial_structure_types.rindex(@ifc::IfcSite)] = ifc_entity
          else
            # Create default IfcBuildingStorey and add there, and check for IfcBuilding and site
            add_default_spatialelement(@ifc::IfcBuildingStorey)
            insert_after(ifc_entity, @ifc::IfcBuildingStorey)
          end
        when @ifc::IfcElementAssembly, @ifc::IfcCurtainWall, @ifc::IfcRoof

          # add to end but check for basic spatial hierarchy
          if (spatial_structure_types & [@ifc::IfcSpace, @ifc::IfcBuildingStorey, @ifc::IfcSite]).empty?
            add_default_spatialelement(@ifc::IfcBuildingStorey)
          end
          @spatial_structure << ifc_entity
        else # IfcProduct, IfcGroup

          # don't add but check for basic spatial hierarchy
          if (spatial_structure_types & [@ifc::IfcSpace, @ifc::IfcBuildingStorey, @ifc::IfcSite]).empty?
            add_default_spatialelement(@ifc::IfcBuildingStorey)
          end
        end
      end

      # Create new default instance of given class and add to entity path
      def add_default_spatialelement(entity_class)
        # find parent type, if entity not present find the next one
        index = @spatial_order.rindex(entity_class) - 1
        parent_class = @spatial_order[index]
        add_default_spatialelement(parent_class) unless get_spatial_structure_types.include?(parent_class)

        parent_index = get_spatial_structure_types.rindex(parent_class)
        parent = @spatial_structure[parent_index]

        # check if default_related_object is already set
        unless parent.default_related_object
          default_parent = entity_class.new(@ifc_model)
          default_parent.name = Types::IfcLabel.new(@ifc_model,
                                                    +'default ' << entity_class.name.split('::').last.split(/(?=[A-Z])/).drop(1).join(' ').downcase)

          # Add new ObjectPlacement without transformation
          default_parent.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model)
          default_parent.objectplacement.relativeplacement = @ifc_model.default_placement
          default_parent.objectplacement.placementrelto = parent.objectplacement if parent.respond_to?(:objectplacement)

          # set default related element
          parent.default_related_object = default_parent
        end
        add(parent.default_related_object)
        set_parent(parent.default_related_object)
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
        when @ifc::IfcSpatialStructureElement
          ifc_entity.parent.add_related_object(ifc_entity)
        else
          case ifc_entity.parent
          when @ifc::IfcSpatialStructureElement
            ifc_entity.parent.add_contained_element(ifc_entity)
          when @ifc::IfcProject, @ifc::IfcProduct, @ifc::IfcCurtainWall, @ifc::IfcElementAssembly
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
        return placement_parent if placement_parent.is_a? @ifc::IfcSpatialStructureElement

        @spatial_structure.find { |entity| entity.is_a? @ifc::IfcSite }
      end
    end
  end
end
