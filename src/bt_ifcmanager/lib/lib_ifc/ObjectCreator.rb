#  ObjectCreator.rb
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

require_relative('IfcGloballyUniqueId.rb')
require_relative('IfcLengthMeasure.rb')

require_relative(File.join('IFC2X3', 'IfcElementAssembly.rb'))
require_relative(File.join('IFC2X3', 'IfcBuilding.rb'))
require_relative(File.join('IFC2X3', 'IfcBuildingStorey.rb'))
require_relative(File.join('IFC2X3', 'IfcBuildingElementProxy.rb'))
require_relative(File.join('IFC2X3', 'IfcCurtainWall.rb'))
require_relative(File.join('IFC2X3', 'IfcGroup.rb'))
require_relative(File.join('IFC2X3', 'IfcLocalPlacement.rb'))
require_relative(File.join('IFC2X3', 'IfcProject.rb'))
require_relative(File.join('IFC2X3', 'IfcSite.rb'))
require_relative(File.join('IFC2X3', 'IfcSpace.rb'))
require_relative(File.join('IFC2X3', 'IfcSpatialStructureElement.rb'))
require_relative(File.join('IFC2X3', 'IfcZone.rb'))

# transformation = the sketchup transformation object that translates back to the geometric_parent
# su_instance = sketchup component instance or group
# su_total_transformation = sketchup total transformation from model root to this instance placement
# geometric_parent = ifc entity above this one in the hierarchy
# spatial_hierarchy = Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
module BimTools::IfcManager
  require File.join(PLUGIN_PATH_LIB, 'layer_visibility.rb')

  # checks the current definition for ifc objects, and calls itself for all nested items
  class ObjectCreator
    include BimTools::IFC2X3

    SPATIAL_ORDER = [
      IfcProject,
      IfcSite,
      IfcBuilding,
      IfcBuildingStorey,
      IfcSpace
    ].freeze

    # def initialize(ifc_model, su_instance, container, containing_entity, geometric_parent, transformation_from_entity, transformation_from_container, site=nil, site_container=nil, building=nil, building_container=nil, building_storey=nil, building_storey_container=nil)
    def initialize(ifc_model, su_instance, su_total_transformation, geometric_parent, spatial_hierarchy = {}, su_material = nil)
      ifc_entity = nil
      definition = su_instance.definition
      su_material = su_instance.material if su_instance.material
      ent_type_name = definition.get_attribute('AppliedSchemaTypes', 'IFC 2x3')
      parent_hex_guid = geometric_parent.globalid&.to_s

      # check if entity_type is part of the entity list that needs exporting
      # also continue if NOT an IFC entity but the parent object IS an entity
      if ifc_model.options[:ifc_entities] == false || ifc_model.options[:ifc_entities].include?(ent_type_name) # || ( ent_type_name.nil? && geometric_parent.is_a?(IfcProduct) && !geometric_parent.is_a?(IfcSpatialStructureElement))

        # Create IFC entity based on the IFC classification in sketchup
        begin
          require_relative File.join('IFC2X3', ent_type_name)
          entity_type = eval(ent_type_name)

          # if a IfcProject then add su_object to the existing project
          # (?) what if there are multiple projects defined?
          if entity_type == IfcProject
            ifc_model.project.su_object = su_instance
            ifc_entity = nil
          else
            ifc_entity = entity_type.new(ifc_model, su_instance)
            if entity_type == IfcRoot
              ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid)
            end
          end

        # LoadError added because require errors are not catched by StandardError
        rescue StandardError, LoadError
          # If not classified as IFC in sketchup AND the parent is an IfcSpatialStructureElement then this is an IfcBuildingElementProxy
          if geometric_parent.is_a?(IfcSpatialStructureElement) || geometric_parent.is_a?(IfcProject)
            ifc_entity = IfcBuildingElementProxy.new(ifc_model, su_instance)
            ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid)
          else # this instance is pure geometry, ifc_entity = nil
            ifc_entity = nil
          end
        end
      end
      
      # Add entity to the spatial hierarchy if it's a IfcSpatialStructureElement
      if ifc_entity.is_a?(IfcSpatialStructureElement)
        spatial_hierarchy[ifc_entity.class] = ifc_entity
      end

      spatial_hierarchy = validate_spatial_hierarchy(ifc_entity, spatial_hierarchy)
     
      # if parent is a IfcGroup, add entity to group 
      if geometric_parent.is_a?(IfcGroup)
        if ifc_entity.is_a?(IfcObjectDefinition)
          if geometric_parent.is_a?(IfcZone)
            if ifc_entity.is_a?(IfcZone) || ifc_entity.is_a?(IfcSpace)
              geometric_parent.add(ifc_entity)
            end
          else
            geometric_parent.add(ifc_entity)
          end
        end
      end

      # validate and correct the parent in the spacialhierarchy
      if ifc_entity && !ifc_entity.is_a?(IfcGroup)
        ifc_entity.parent = get_parent_ifc(ifc_entity, geometric_parent, spatial_hierarchy)

        # Add entity to the model structure
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

      # if this SU object is not an IFC Entity then set the parent entity as Ifc Entity
      ifc_entity ||= geometric_parent
      
      # corrigeren voor het geval beide transformties dezelfde verschaling hebben, die mag niet met inverse geneutraliseerd worden
      # er zou in de ifc_total_transformation eigenlijk geen verschaling mogen zitten.
      # wat mag er wel in zitten? wel verdraaiing en verplaatsing.

      # calculate the total transformation
      su_total_transformation *= su_instance.transformation

      # create objectplacement for ifc_entity
      # set objectplacement based on transformation
      if ifc_entity.is_a?(IfcProduct)
        if ifc_entity.parent.is_a?(IfcProduct)
          ifc_entity.objectplacement = IfcLocalPlacement.new(ifc_model, su_total_transformation, ifc_entity.parent.objectplacement)
        else
          ifc_entity.objectplacement = IfcLocalPlacement.new(ifc_model, su_total_transformation)
        end

        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        # could be better set from within IfcBuildingStorey?
        if ifc_entity.is_a?(IfcBuildingStorey)
          elevation = ifc_entity.objectplacement.ifc_total_transformation.origin.z.to_mm
          ifc_entity.elevation = BimTools::IfcManager::IfcLengthMeasure.new(elevation)
        end

        # unless ifc_entity.parent.is_a?(IfcProject) # (?) check unnecessary?
        #  ifc_entity.objectplacement.placementrelto = ifc_entity.parent.objectplacement
        # end
      end

      # find sub-objects (geometry and entities)
      faces = []
      entities = definition.entities
      definition_count = entities.length
      i = 0
      while i < definition_count
        ent = entities[i]

        # skip hidden objects if skip-hidden option is set
        # if ifc_model.options[:hidden] == true
        #   if !ent.hidden? || BimTools::IfcManager::layer_visible?(ent.layer)
        unless ifc_model.options[:hidden] == false && (ent.hidden? || !BimTools::IfcManager.layer_visible?(ent.layer))
          case ent
          when Sketchup::Group, Sketchup::ComponentInstance
            
            # Add parent to the next entity's spatial hierarchy if it's a IfcSpatialStructureElement
            if ifc_entity.is_a?(IfcSpatialStructureElement)
              spatial_hierarchy[ifc_entity.class] = ifc_entity
            end
            ObjectCreator.new(ifc_model, ent, su_total_transformation, ifc_entity, spatial_hierarchy.clone, su_material)
          when Sketchup::Face
            faces << ent if ifc_model.options[:geometry]
          end
        end
        i += 1
      end

      # calculate the local transformation
      # if the SU object if not an IFC entity, then BREP needs to be transformed with SU object transformation
      if !ifc_entity.is_a?(IfcProduct) || ifc_entity.is_a?(IfcGroup) || ifc_entity.parent.is_a?(IfcProject)
        brep_transformation = su_total_transformation
      else
        brep_transformation = ifc_entity.objectplacement.ifc_total_transformation.inverse * su_total_transformation
      end

      # create geometry from faces
      # (!) skips any geometry placed inside objects NOT of the type IfcProduct
      if !faces.empty? && ifc_entity.is_a?(IfcProduct)
        ifc_entity.create_representation(faces, brep_transformation, su_material)
      end
      # # create geometry from faces
      # unless faces.empty? || ifc_entity.is_a?(IfcProject) #(?) skip any geometry placed inside IfcProject object?
      #   ifc_entity.create_representation(faces, brep_transformation, su_material)
      # end
    end

    # Find the parent entity for given entity
    #   and check the spatial hierarchy along the way
    def get_parent_ifc(ifc_entity, geometric_parent, spatial_hierarchy)
      puts(spatial_hierarchy.keys)

      # If ifc_entity is in the spatial hierarchy (i.a. is a IfcSpatialStructureElement)
      # if spatial_hierarchy.has_value?(ifc_entity)
      if ifc_entity.is_a?(IfcSpatialStructureElement)
        parent_type_index = SPATIAL_ORDER.index(ifc_entity.class) - 1
      
      # IfcElementAssembly and IfcCurtainWall are special cases with direct child objects
      elsif geometric_parent.is_a?(IfcElementAssembly) || geometric_parent.is_a?(IfcCurtainWall)
        return geometric_parent
      else

        # Get the highest SPATIAL_ORDER index from spatial_hierarchy
        parent_type_index = 0
        spatial_hierarchy.each_key do |entity|
          if SPATIAL_ORDER.include?(entity)
            entity_index = SPATIAL_ORDER.index(entity)
            if entity_index > parent_type_index
              parent_type_index = entity_index
            end
          end
        end
      end

      # Return parent entity
      return spatial_hierarchy[SPATIAL_ORDER[parent_type_index]]
    end

    def validate_spatial_hierarchy(ifc_entity, spatial_hierarchy)

      # Get the highest SPATIAL_ORDER index from spatial_hierarchy
      entity_type_index = 0
      spatial_hierarchy.each_key do |entity|
        if SPATIAL_ORDER.include?(entity)
          entity_index = SPATIAL_ORDER.index(entity)
          if entity_index > entity_type_index
            entity_type_index = entity_index
          end
        end
      end

      # Check if minimal spatial structure exists (IfcSite)
      unless entity_type_index >= SPATIAL_ORDER.index(IfcSite)
        entity_type_index = SPATIAL_ORDER.index(IfcBuildingStorey)
      end

      # Fill missing objects in spatial tree
      i = 1 # start after IfcProject because that's always present
      while i <= entity_type_index
        unless spatial_hierarchy.key?(SPATIAL_ORDER[i])
          spatial_hierarchy[SPATIAL_ORDER[i]] = spatial_hierarchy[SPATIAL_ORDER[i-1]].get_default_related_object
        end
        i += 1
      end

      return spatial_hierarchy
    end
  end
end