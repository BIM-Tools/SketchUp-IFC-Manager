# frozen_string_literal: true

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

module BimTools::IfcManager
  require File.join(PLUGIN_PATH_LIB, 'layer_visibility.rb')

  class ObjectCreator
    include BimTools::IFC2X3

    SPATIAL_ORDER = [
      IfcProject,
      IfcSite,
      IfcBuilding,
      IfcBuildingStorey,
      IfcSpace
    ].freeze

    # This creator class creates the correct IFC entity for the given sketchup object and it's children
    #
    # @parameter ifc_model [IfcManager::IfcModel] The IFC model in which the new IFC entity must be added
    # @parameter su_instance [Sketchup::ComponentInstance, Sketchup::Group] The sketchup component instance or group for which an IFC entity must be created
    # @parameter su_total_transformation [Geom::Transformation] The combined transformation of all parent sketchup objects
    # @parameter geometric_parent [IFC ENTITY] The IFC entity that is the direct geometric parent in the sketchup model
    # @parameter spatial_hierarchy [Hash<BimTools::IfcManager::IFC2X3::IfcSpatialStructureElement>] Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
    # @parameter su_material [Sketchup::Material] The parent sketchup objects material which will be used when the given one does not have a directly associated material
    #
    def initialize(ifc_model, su_instance, su_total_transformation, geometric_parent, spatial_hierarchy = {}, su_material = nil)
      ifc_entity = nil?
      @ifc_model = ifc_model
      @geometric_parent = geometric_parent
      @spatial_hierarchy = spatial_hierarchy
      ent_type_name = su_instance.definition.get_attribute('AppliedSchemaTypes', 'IFC 2x3')
      parent_hex_guid = @geometric_parent.globalid&.to_s

      # Add the current sketchup object's transformation to the total transformation
      @su_total_transformation = su_total_transformation * su_instance.transformation

      # check if entity_type is part of the entity list that needs exporting
      if @ifc_model.options[:ifc_entities] == false || ent_type_name.nil? || @ifc_model.options[:ifc_entities].include?(ent_type_name)

        # Create IFC entity based on the IFC classification in sketchup
        begin
          require_relative File.join('IFC2X3', ent_type_name)
          entity_type = eval(ent_type_name)

          # if a IfcProject then add su_object to the existing project
          # (?) what if there are multiple projects defined?
          if entity_type == IfcProject
            @ifc_model.project.su_object = su_instance
            ifc_entity = nil
          else
            ifc_entity = entity_type.new(@ifc_model, su_instance)
            if entity_type == IfcRoot
              ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid)
            end
          end
          construct_entity(ifc_entity)
          create_nested_objects(ifc_entity, su_instance, su_material)

        # LoadError added because require errors are not catched by StandardError
        rescue StandardError, LoadError
          # If not classified as IFC in sketchup AND the parent is an IfcSpatialStructureElement then this is an IfcBuildingElementProxy
          if @geometric_parent.is_a?(IfcSpatialStructureElement) || @geometric_parent.is_a?(IfcProject)
            ifc_entity = IfcBuildingElementProxy.new(@ifc_model, su_instance)
            ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid)
            construct_entity(ifc_entity)
            create_nested_objects(ifc_entity, su_instance, su_material)
          else # this instance is pure geometry and will be part of the parent entity
            create_nested_objects(geometric_parent, su_instance, su_material)
          end
        end
      end
    end

    private

    # Constructs the IFC entity
    #
    # @parameter ifc_entity
    #
    def construct_entity(ifc_entity)
      # Add entity to the spatial hierarchy if it's a IfcSpatialStructureElement
      if ifc_entity.is_a?(IfcSpatialStructureElement)
        @spatial_hierarchy[ifc_entity.class] = ifc_entity
      end

      validate_spatial_hierarchy

      # if parent is a IfcGroup, add entity to group
      if @geometric_parent.is_a?(IfcGroup)
        if ifc_entity.is_a?(IfcObjectDefinition)
          if @geometric_parent.is_a?(IfcZone)
            if ifc_entity.is_a?(IfcZone) || ifc_entity.is_a?(IfcSpace)
              @geometric_parent.add(ifc_entity)
            end
          else
            @geometric_parent.add(ifc_entity)
          end
        end
      end

      # validate and correct the parent in the spacialhierarchy
      if ifc_entity && !ifc_entity.is_a?(IfcGroup)
        ifc_entity.parent = get_parent_ifc(ifc_entity)

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

      # create objectplacement for ifc_entity
      # set objectplacement based on transformation
      if ifc_entity.is_a?(IfcProduct)
        if ifc_entity.parent.is_a?(IfcProduct)
          ifc_entity.objectplacement = IfcLocalPlacement.new(@ifc_model, @su_total_transformation, ifc_entity.parent.objectplacement)
        else
          ifc_entity.objectplacement = IfcLocalPlacement.new(@ifc_model, @su_total_transformation)
        end

        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        #   could be better set from within IfcBuildingStorey?
        if ifc_entity.is_a?(IfcBuildingStorey)
          elevation = ifc_entity.objectplacement.ifc_total_transformation.origin.z.to_mm
          ifc_entity.elevation = BimTools::IfcManager::IfcLengthMeasure.new(elevation)
        end
      end
    end

    # find nested objects (geometry and entities)
    #
    # @parameter ifc_entity
    # @parameter su_instance
    # @parameter su_material
    #
    def create_nested_objects(ifc_entity, su_instance, su_material)
      faces = []
      definition = su_instance.definition
      su_material = su_instance.material if su_instance.material
      entities = definition.entities
      definition_count = entities.length
      i = 0
      while i < definition_count
        ent = entities[i]

        # skip hidden objects if skip-hidden option is set
        # if @ifc_model.options[:hidden] == true
        #   if !ent.hidden? || BimTools::IfcManager::layer_visible?(ent.layer)
        unless @ifc_model.options[:hidden] == false && (ent.hidden? || !BimTools::IfcManager.layer_visible?(ent.layer))
          case ent
          when Sketchup::Group, Sketchup::ComponentInstance

            # Add parent to the next entity's spatial hierarchy if it's a IfcSpatialStructureElement
            if ifc_entity.is_a?(IfcSpatialStructureElement)
              @spatial_hierarchy[ifc_entity.class] = ifc_entity
            end
            ObjectCreator.new(@ifc_model, ent, @su_total_transformation, ifc_entity, @spatial_hierarchy.clone, su_material)
          when Sketchup::Face
            faces << ent if @ifc_model.options[:geometry]
          end
        end
        i += 1
      end

      # calculate the local transformation
      # if the SU object if not an IFC entity, then BREP needs to be transformed with SU object transformation
      if !ifc_entity.is_a?(IfcProduct) || ifc_entity.is_a?(IfcGroup) || ifc_entity.parent.is_a?(IfcProject)
        brep_transformation = @su_total_transformation
      else
        brep_transformation = ifc_entity.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
      end

      # create geometry from faces
      # (!) skips any geometry placed inside objects NOT of the type IfcProduct
      unless faces.empty? # && ifc_entity.is_a?(IfcProduct)
        if ifc_entity
          ifc_entity.create_representation(faces, brep_transformation, su_material)
        else
          ifc_entity.parent.create_representation(faces, brep_transformation, su_material)
        end
      end
    end

    # Finds the parent entity for given IFC entity and completes the spatial hierarchy
    #
    # @parameter ifc_entity
    #
    def get_parent_ifc(ifc_entity)
      # If ifc_entity is in the spatial hierarchy (i.a. is a IfcSpatialStructureElement)
      # if @spatial_hierarchy.has_value?(ifc_entity)
      if ifc_entity.is_a?(IfcSpatialStructureElement)
        parent_type_index = SPATIAL_ORDER.index(ifc_entity.class) - 1

      # IfcElementAssembly and IfcCurtainWall are special cases with direct child objects
      elsif @geometric_parent.is_a?(IfcElementAssembly) || @geometric_parent.is_a?(IfcCurtainWall)
        return @geometric_parent
      else

        # Get the highest SPATIAL_ORDER index from @spatial_hierarchy
        parent_type_index = 0
        @spatial_hierarchy.each_key do |entity|
          next unless SPATIAL_ORDER.include?(entity)

          entity_index = SPATIAL_ORDER.index(entity)
          parent_type_index = entity_index if entity_index > parent_type_index
        end
      end

      # Return parent entity
      @spatial_hierarchy[SPATIAL_ORDER[parent_type_index]]
    end

    # Validates and updates the spatial hierarchy for the current object.
    #
    def validate_spatial_hierarchy
      entity_type_index = spatial_hierarchy_highest_index

      # Check if minimal spatial structure exists (IfcSite)
      unless entity_type_index >= SPATIAL_ORDER.index(IfcSite)
        entity_type_index = SPATIAL_ORDER.index(IfcBuildingStorey)
      end

      # Fill missing objects in spatial tree
      i = 1 # start after IfcProject because that's always present
      while i <= entity_type_index
        unless @spatial_hierarchy.key?(SPATIAL_ORDER[i])
          @spatial_hierarchy[SPATIAL_ORDER[i]] = @spatial_hierarchy[SPATIAL_ORDER[i - 1]].get_default_related_object
        end
        i += 1
      end
    end

    # Get the highest SPATIAL_ORDER index from @spatial_hierarchy
    #
    def spatial_hierarchy_highest_index
      entity_type_index = 0
      @spatial_hierarchy.each_key do |entity|
        next unless SPATIAL_ORDER.include?(entity)

        entity_index = SPATIAL_ORDER.index(entity)
        entity_type_index = entity_index if entity_index > entity_type_index
      end
      entity_type_index
    end
  end
end
