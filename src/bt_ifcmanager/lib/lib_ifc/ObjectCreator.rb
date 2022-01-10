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

require_relative('IfcGloballyUniqueId')
require_relative('IfcLengthMeasure')
require_relative('entity_path')

module BimTools::IfcManager
  require File.join(PLUGIN_PATH_LIB, 'layer_visibility.rb')

  class ObjectCreator

    # This creator class creates the correct IFC entity for the given sketchup object and it's children
    #
    # @parameter ifc_model [IfcManager::IfcModel] The IFC model in which the new IFC entity must be added
    # @parameter su_instance [Sketchup::ComponentInstance, Sketchup::Group] The sketchup component instance or group for which an IFC entity must be created
    # @parameter su_total_transformation [Geom::Transformation] The combined transformation of all parent sketchup objects
    # @parameter placement_parent [IFC ENTITY] The IFC entity that is the direct geometric parent in the sketchup model
    # @parameter entity_path [Hash<BimTools::IfcManager::IFC2X3::IfcSpatialStructureElement>] Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
    # @parameter su_material [Sketchup::Material] The parent sketchup objects material which will be used when the given one does not have a directly associated material
    #
    def initialize(ifc_model, su_instance, su_total_transformation, placement_parent = nil, entity_path = nil, su_material = nil)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @ifc_model = ifc_model
      @entity_path = EntityPath.new(@ifc_model, entity_path)
      ent_type_name = su_instance.definition.get_attribute('AppliedSchemaTypes',
                                                           BimTools::IfcManager::Settings.ifc_version)
      su_material = su_instance.material if su_instance.material

      # Add the current sketchup object's transformation to the total transformation
      @su_total_transformation = su_total_transformation * su_instance.transformation

      # check if entity is one of the entities that need to be exported (and possibly it's nested entities)
      if @ifc_model.su_entities.empty?
        if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(ent_type_name)
          create_ifc_entity(ent_type_name, su_instance, placement_parent, su_material)
        end
      elsif @ifc_model.su_entities.include?(su_instance)
        if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(ent_type_name)
          create_ifc_entity(ent_type_name, su_instance, placement_parent, su_material)
        end
      else
        create_nested_objects(placement_parent, su_instance, su_material)
      end
    end

    private

    # Create IFC entity based on the IFC classification in sketchup
    def create_ifc_entity(ent_type_name, su_instance, placement_parent = nil, su_material = nil)
      parent_hex_guid = placement_parent.globalid&.to_hex if placement_parent

      # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecated in IFC 4
      ent_type_name = 'IfcWall' if ent_type_name == 'IfcWallStandardCase'

      entity_type = BimTools::IfcManager::Settings.ifc_module.const_get(ent_type_name) if ent_type_name

      # All unclassified and non-existent objects are mapped to IfcBuildingElementProxy
      entity_type ||= @ifc::IfcBuildingElementProxy

      # if a IfcProject then add su_object to the existing project
      # (?) what if there are multiple projects defined?
      if entity_type == @ifc::IfcProject

        # TODO: set all correct parameters for IfcProject!!!
        @ifc_model.project.su_object = su_instance
        ifc_entity = @ifc_model.project
      else
        ifc_entity = entity_type.new(@ifc_model, su_instance)
      end

      ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid) if entity_type < @ifc::IfcRoot

      @entity_path.add(ifc_entity)
      construct_entity(ifc_entity, placement_parent)
      faces = create_nested_objects(ifc_entity, su_instance, su_material)
      create_geometry(su_instance.definition, ifc_entity, su_material, faces)
    end

    # Constructs the IFC entity
    #
    # @parameter ifc_entity
    #
    def construct_entity(ifc_entity, placement_parent)
      # if parent is a IfcGroup, add entity to group
      if placement_parent.is_a?(@ifc::IfcGroup) && ifc_entity.is_a?(@ifc::IfcObjectDefinition)
        if placement_parent.is_a?(@ifc::IfcZone)
          placement_parent.add(ifc_entity) if ifc_entity.is_a?(@ifc::IfcZone) || ifc_entity.is_a?(@ifc::IfcSpace)
        else
          placement_parent.add(ifc_entity)
        end
      end

      # create objectplacement for ifc_entity
      # set objectplacement based on transformation
      if ifc_entity.is_a?(@ifc::IfcProduct)
        @entity_path.set_parent(ifc_entity)
        if ifc_entity.parent.is_a?(@ifc::IfcProduct)
          ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, @su_total_transformation,
                                                             ifc_entity.parent.objectplacement)
        else
          ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, @su_total_transformation)
        end

        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        #   could be better set from within IfcBuildingStorey?
        if ifc_entity.is_a?(@ifc::IfcBuildingStorey)
          elevation = ifc_entity.objectplacement.ifc_total_transformation.origin.z
          ifc_entity.elevation = BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, elevation)
        end
      end
    end

    # find nested objects (geometry and entities)
    #
    # @parameter ifc_entity
    # @parameter su_instance
    # @parameter su_material
    #
    # @return [Array] direct sketchup geometry
    def create_nested_objects(ifc_entity, su_instance, su_material)
      faces = []
      definition = su_instance.definition

      # (!)(?) Do we need to update su_material?
      # su_material = su_instance.material if su_instance.material

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

            ObjectCreator.new(@ifc_model, ent, @su_total_transformation, ifc_entity, @entity_path, su_material)
          when Sketchup::Face
            faces << ent if @ifc_model.options[:geometry]
          end
        end
        i += 1
      end
      faces
    end

    def create_geometry(definition, ifc_entity, su_material, faces)
      # calculate the local transformation
      # if the SU object if not an IFC entity, then BREP needs to be transformed with SU object transformation
      if !ifc_entity.is_a?(@ifc::IfcProduct) || ifc_entity.is_a?(@ifc::IfcGroup) || ifc_entity.parent.is_a?(@ifc::IfcProject)
        brep_transformation = @su_total_transformation
      else
        brep_transformation = ifc_entity.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
      end

      # create geometry from faces
      # (!) skips any geometry placed inside objects NOT of the type IfcProduct
      unless faces.empty?
        if ifc_entity
          ifc_entity.create_representation(definition, faces, brep_transformation, su_material)
        else
          ifc_entity.parent.create_representation(definition, faces, brep_transformation, su_material)
        end
      end
    end
  end
end
