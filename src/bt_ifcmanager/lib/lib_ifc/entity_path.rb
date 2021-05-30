#  entity_path.rb
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

# require_relative(File.join('IFC2X3', 'IfcElementAssembly.rb'))
# require_relative(File.join('IFC2X3', 'IfcBuilding.rb'))
# require_relative(File.join('IFC2X3', 'IfcBuildingStorey.rb'))
# require_relative(File.join('IFC2X3', 'IfcCurtainWall.rb'))
# require_relative(File.join('IFC2X3', 'IfcProduct.rb'))
# require_relative(File.join('IFC2X3', 'IfcProject.rb'))
# require_relative(File.join('IFC2X3', 'IfcSite.rb'))
# require_relative(File.join('IFC2X3', 'IfcSpace.rb'))
# require_relative(File.join('IFC2X3', 'IfcSpatialStructureElement.rb'))

module BimTools::IfcManager

  # The EntityPath class represents the entity path to a given entity within the IFC project spatial hierarchy.
  #
  class EntityPath
    include BimTools::IFC2X3

    SPATIAL_ORDER = [
      IfcProject,
      IfcSite,
      IfcBuilding,
      IfcBuildingStorey,
      IfcSpace
    ].freeze

    # This creator class creates the EntityPath object for a specific IFC entity
    #
    # @parameter ifc_entity [BimTools::IfcManager::IFC2X3::IfcProduct] IFC Entity
    # @parameter spatial_hierarchy [Hash<BimTools::IfcManager::IFC2X3::IfcSpatialStructureElement>] Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
    #
    def initialize( ifc_model, entity_path = nil )
      @ifc_model = ifc_model
      if entity_path
        @entity_path = entity_path.to_a.clone
      else
        @entity_path = []
      end
    end

    # Insert given entity into entity path after given type
    #
    # @parameter ifc_entity [BimTools::IFC2X3::IfcProduct]
    # @parameter ifc_type [BimTools::IFC2X3::IfcProduct] class
    #
    def insert_after(ifc_entity, ifc_type)
      index = path_types().rindex(ifc_type)
      index += 1
      @entity_path.insert(index, ifc_entity)
    end

    def add(ifc_entity)
      entity_path_types = path_types()
      case ifc_entity
      when IfcProject
        #(!) Check!!!
        @entity_path[0] = ifc_entity
      when IfcSite
        if entity_path_types.include? IfcSite
          # Add as partial IfcSite
          # TODO fix option to use partial sites
          # parent_site = @entity_path[path_types().rindex(IfcSite)]
          # path = ["IFC 2x3", "IfcSite", "CompositionType", "IfcElementCompositionEnum"]
          # if parent_site.su_object.definition.get_classification_value(path) == "complex" && ifc_entity.su_object.definition.get_classification_value(path) == "partial"
          #   insert_after(ifc_entity,IfcSite)
          # else
          #   @entity_path[path_types().rindex(IfcSite)] = ifc_entity
          # end

          @entity_path[path_types().rindex(IfcSite)] = ifc_entity
        elsif entity_path_types.include? IfcProject
          insert_after(ifc_entity,IfcProject)
        end
      when IfcBuilding
        if entity_path_types.include? IfcBuilding
          # Add as partial IfcBuilding
          # insert_after(ifc_entity,IfcBuilding)
          @entity_path[path_types().rindex(IfcBuilding)] = ifc_entity
        elsif entity_path_types.include? IfcSite
          insert_after(ifc_entity,IfcSite)
        else
          # Create default Site and add there
          add_default_spatialelement(BimTools::IFC2X3::IfcSite)
          insert_after(ifc_entity,IfcSite)
        end
      when IfcBuildingStorey
        if entity_path_types.include? IfcBuildingStorey
          # Add as partial IfcBuildingStorey
          # insert_after(ifc_entity,IfcBuildingStorey)
          @entity_path[path_types().rindex(IfcBuildingStorey)] = ifc_entity
        elsif entity_path_types.include? IfcBuilding
          insert_after(ifc_entity,IfcBuilding)
        else
          # Create default IfcBuilding and add there, and check for site
          add_default_spatialelement(BimTools::IFC2X3::IfcBuilding)
          insert_after(ifc_entity,IfcBuilding)
        end
      when IfcSpace
        if entity_path_types.include? IfcSpace
          # Add as partial IfcBuildingStorey
          # insert_after(ifc_entity,IfcSpace)
          @entity_path[path_types().rindex(IfcSpace)] = ifc_entity
        elsif entity_path_types.include? IfcBuildingStorey
          # insert_after(ifc_entity,IfcBuildingStorey)
          @entity_path[path_types().rindex(IfcBuildingStorey)] = ifc_entity
        elsif entity_path_types.include? IfcSite
          # Add as outside space
          # insert_after(ifc_entity,IfcSite)
          @entity_path[path_types().rindex(IfcSite)] = ifc_entity
        else
          # Create default IfcBuildingStorey and add there, and check for IfcBuilding and site
          add_default_spatialelement(BimTools::IFC2X3::IfcBuildingStorey)
          insert_after(ifc_entity,IfcBuildingStorey)
        end
      when IfcElementAssembly, IfcCurtainWall

        # add to end but check for basic spatial hierarchy
        if (entity_path_types & [IfcSpace,IfcBuildingStorey,IfcSite]).empty?
          add_default_spatialelement(BimTools::IFC2X3::IfcBuildingStorey)
        end
        @entity_path << ifc_entity
      else # IfcProduct

        # don't add but check for basic spatial hierarchy
        if (entity_path_types & [IfcSpace,IfcBuildingStorey,IfcSite]).empty?
          add_default_spatialelement(BimTools::IFC2X3::IfcBuildingStorey)
        end
      end
    end

    # Create new default instance of given class and add to entity path
    def add_default_spatialelement(entity_class)

      # find parent type, if entity not present find the next one
      index = SPATIAL_ORDER.rindex(entity_class) -1
      parent_class = SPATIAL_ORDER[index]
      unless path_types().include?(parent_class)
        add_default_spatialelement(parent_class)
      end
      
      parent_index = path_types().rindex(parent_class)
      parent = @entity_path[parent_index]

      # check if default_related_object is already set
      unless parent.default_related_object
        default_parent = entity_class.new( @ifc_model )
        default_parent.name = BimTools::IfcManager::IfcLabel.new("default " << entity_class.name.split('::').last.split(/(?=[A-Z])/).drop(1).join(" ").downcase)
        
        # set default related element
        parent.default_related_object = default_parent
      end
      self.add(parent.default_related_object)
      set_parent(parent.default_related_object)
    end

    def to_a()
      return @entity_path
    end

    def path_types()
      @entity_path.map(&:class)
    end

    # Add entity to the model structure
    def set_parent(ifc_entity)
      index = @entity_path.index(ifc_entity)
      if index
        if index > 1
          parent = @entity_path[index - 1]
        else
          parent = @entity_path[0]
        end
      else
        parent = @entity_path[-1]
      end
      ifc_entity.parent = parent
      case ifc_entity
      when IfcSpatialStructureElement
        ifc_entity.parent.add_related_object(ifc_entity)
      else
        case ifc_entity.parent
        when IfcSpatialStructureElement
          ifc_entity.parent.add_contained_element(ifc_entity)
        when IfcProject, IfcProduct, IfcCurtainWall, IfcElementAssembly
          ifc_entity.parent.add_related_object(ifc_entity)
        end
      end
    end
  end
end