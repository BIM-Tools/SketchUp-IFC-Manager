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
    # @param ifc_model [IfcManager::IfcModel] The IFC model in which the new IFC entity must be added
    # @param su_instance [Sketchup::ComponentInstance, Sketchup::Group] The sketchup component instance or group for which an IFC entity must be created
    # @param su_total_transformation [Geom::Transformation] The combined transformation of all parent sketchup objects
    # @param placement_parent [IFC ENTITY] The IFC entity that is the direct geometric parent in the sketchup model
    # @param entity_path [Hash<BimTools::IfcManager::IFC2X3::IfcSpatialStructureElement>] Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
    # @param su_material [Sketchup::Material] The parent sketchup objects material which will be used when the given one does not have a directly associated material
    def initialize(ifc_model, su_instance, su_total_transformation, placement_parent = nil, entity_path = nil, su_material = nil, su_layer = nil)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @ifc_model = ifc_model
      @entity_path = EntityPath.new(@ifc_model, entity_path)
      ent_type_name = su_instance.definition.get_attribute('AppliedSchemaTypes',
                                                           BimTools::IfcManager::Settings.ifc_version)
      su_material = su_instance.material if su_instance.material
      su_layer = su_instance.layer if su_instance.layer.name != 'Layer0' || su_layer.nil?

      # Add the current sketchup object's transformation to the total transformation
      @su_total_transformation = su_total_transformation * su_instance.transformation

      # check if entity is one of the entities that need to be exported (and possibly it's nested entities)
      if @ifc_model.su_entities.empty?
        if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(ent_type_name)
          create_ifc_entity(ent_type_name, su_instance, placement_parent, su_material, su_layer)
        end
      elsif @ifc_model.su_entities.include?(su_instance)
        if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(ent_type_name)
          create_ifc_entity(ent_type_name, su_instance, placement_parent, su_material, su_layer)
        end
      else
        create_nested_objects(placement_parent, su_instance, su_material, su_layer)
      end
    end

    private

    # Create IFC entity based on the IFC classification in sketchup
    def create_ifc_entity(ent_type_name, su_instance, placement_parent = nil, su_material = nil, su_layer = nil)
      # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecation in IFC 4
      ent_type_name = 'IfcWall' if ent_type_name == 'IfcWallStandardCase'

      entity_type = BimTools::IfcManager::Settings.ifc_module.const_get(ent_type_name) if ent_type_name

      parent_hex_guid = placement_parent.globalid.to_hex if placement_parent && placement_parent.globalid

      case entity_type
      when nil

        # If sketchup object is not an IFC entity it must become part of the parent object geometry
        faces = create_nested_objects(placement_parent, su_instance, su_material, su_layer)
        create_geometry(su_instance.definition, nil, placement_parent, su_material, su_layer, faces)
      when @ifc::IfcProject

        # @todo: set all correct parameters for IfcProject!!!
        @ifc_model.project.su_object = su_instance
        ifc_entity = @ifc_model.project
        ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid) if entity_type < @ifc::IfcRoot
        @entity_path.add(ifc_entity)
        construct_entity(ifc_entity, placement_parent)
        faces = create_nested_objects(ifc_entity, su_instance, su_material, su_layer)
        create_geometry(su_instance.definition, ifc_entity, placement_parent, su_material, su_layer, faces)
      else
        ifc_entity = entity_type.new(@ifc_model, su_instance)
        ifc_entity.globalid = IfcGloballyUniqueId.new(su_instance, parent_hex_guid) if entity_type < @ifc::IfcRoot

        @entity_path.add(ifc_entity)
        construct_entity(ifc_entity, placement_parent)
        faces = create_nested_objects(ifc_entity, su_instance, su_material, su_layer)
        create_geometry(su_instance.definition, ifc_entity, placement_parent, su_material, su_layer, faces)
      end
    end

    # Constructs the IFC entity
    #
    # @param ifc_entity
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
    # @param ifc_entity
    # @param su_instance
    # @param su_material
    # @return [Array<Sketchup::Face>] direct sketchup geometry
    def create_nested_objects(ifc_entity, su_instance, su_material, su_layer)
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
            ObjectCreator.new(@ifc_model,
                              ent, @su_total_transformation,
                              ifc_entity,
                              @entity_path,
                              su_material,
                              su_layer)
          when Sketchup::Face
            faces << ent if @ifc_model.options[:geometry]
          end
        end
        i += 1
      end
      faces
    end

    def create_geometry(definition, ifc_entity, placement_parent = nil, su_material, su_layer, faces)
      # calculate the local transformation
      # if the SU object if not an IfcProduct (cannot have a representation ), then BREP needs to be transformed with SU object transformation
      brep_transformation = if ifc_entity.is_a?(@ifc::IfcProduct)
                              ifc_entity.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
                            else
                              @su_total_transformation
                            end

      # create geometry from faces
      # (!) skips any geometry placed inside objects NOT of the type IfcProduct
      unless faces.empty?
        case ifc_entity

        # IfcZone is a special kind of IfcGroup that can only include IfcSpace objects
        when @ifc::IfcZone
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'space geometry'
                            end
          sub_entity = @ifc::IfcSpace.new(@ifc_model, nil)
          sub_entity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, sub_entity_name)
          definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
          sub_entity.representation = definition_manager.create_representation(faces,
                                                                               brep_transformation,
                                                                               su_material,
                                                                               su_layer)
          sub_entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, Geom::Transformation.new)

          sub_entity.compositiontype = :element if sub_entity.respond_to?(:compositiontype=)
          sub_entity.interiororexteriorspace = :notdefined if sub_entity.respond_to?(:interiororexteriorspace=)

          # Add to spatial hierarchy
          @entity_path.add(sub_entity)
          @entity_path.set_parent(sub_entity)

          # Add created space to the zone
          ifc_entity.add(sub_entity)

        when @ifc::IfcProject
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'project geometry'
                            end
          sub_entity = @ifc::IfcBuildingElementProxy.new(@ifc_model, nil)
          sub_entity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, sub_entity_name)
          definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
          sub_entity.representation = definition_manager.create_representation(faces,
                                                                               brep_transformation,
                                                                               su_material,
                                                                               su_layer)
          sub_entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, Geom::Transformation.new)

          sub_entity.predefinedtype = :notdefined if sub_entity.respond_to?(:predefinedtype=)
          sub_entity.compositiontype = :element if sub_entity.respond_to?(:compositiontype=)

          # Add to spatial hierarchy
          @entity_path.add(sub_entity)
        # @entity_path.set_parent(sub_entity)

        # An IfcGroup or IfcProject has no geometry so all Sketchup geometry is embedded in a IfcBuildingElementProxy
        #   IfcGroup is also the supertype of IfcSystem
        #   (?) mapped items?
        when @ifc::IfcGroup
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'group geometry'
                            end
          sub_entity = @ifc::IfcBuildingElementProxy.new(@ifc_model, nil)
          sub_entity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, sub_entity_name)
          definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
          sub_entity.representation = definition_manager.create_representation(faces,
                                                                               brep_transformation,
                                                                               su_material,
                                                                               su_layer)
          sub_entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, Geom::Transformation.new)

          sub_entity.predefinedtype = :notdefined if sub_entity.respond_to?(:predefinedtype=)
          sub_entity.compositiontype = :element if sub_entity.respond_to?(:compositiontype=)

          # Add to spatial hierarchy
          @entity_path.add(sub_entity)
          @entity_path.set_parent(sub_entity)
          ifc_entity.add(sub_entity)

        # When a Sketchup group/component is not classified as an IFC entity it should
        #   become part of the parent object geometry if the parent can have geometry
        when nil
          definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
          if placement_parent.respond_to? :representation
            transformation = placement_parent.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
            if placement_parent_representation = placement_parent.representation
              brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
              representation_items = placement_parent_representation.representations.first.items
              if representation_items.first.respond_to? :mappingsource # IfcMappedItem
                representation_items.first.mappingsource.mappedrepresentation.items.add(brep)
              else
                representation_items.add(brep)
              end
            else
              placement_parent.representation = definition_manager.create_representation(faces,
                                                                                         transformation,
                                                                                         su_material,
                                                                                         su_layer)
            end
          else
            entity = @ifc::IfcBuildingElementProxy.new(@ifc_model, nil)
            entity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, definition.name)
            definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
            entity.representation = definition_manager.create_representation(faces,
                                                                             brep_transformation,
                                                                             su_material,
                                                                             su_layer)
            entity.objectplacement = @ifc::IfcLocalPlacement.new(@ifc_model, Geom::Transformation.new)

            # IFC 4
            entity.predefinedtype = :notdefined if entity.respond_to?(:predefinedtype=)

            # IFC 2x3
            entity.compositiontype = :element if entity.respond_to?(:compositiontype=)

            # Add to spatial hierarchy
            @entity_path.add(entity)
            @entity_path.set_parent(entity)

            # create materialassociation
            unless @ifc_model.materials.include?(su_material)
              @ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(@ifc_model, su_material)
            end

            # add product to materialassociation
            @ifc_model.materials[su_material].add_to_material(entity)
          end
        else
          definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
          ifc_entity.representation = definition_manager.create_representation(faces,
                                                                               brep_transformation,
                                                                               su_material,
                                                                               su_layer)
        end
      end
    end
  end
end
