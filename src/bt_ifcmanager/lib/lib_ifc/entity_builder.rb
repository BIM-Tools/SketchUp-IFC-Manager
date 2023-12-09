# frozen_string_literal: true

#  entity_builder.rb
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

require_relative 'ifc_types'
require_relative 'IfcGloballyUniqueId'
require_relative 'spatial_structure'
require_relative 'ifc_project_builder'

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'layer_visibility')

    class EntityBuilder
      # This creator class creates the correct IFC entity for the given sketchup object and it's children
      #
      # @param [IfcManager::IfcModel] ifc_model The IFC model in which the new IFC entity must be added
      # @param [Sketchup::ComponentInstance, Sketchup::Group] su_instance The sketchup component instance or group for which an IFC entity must be created
      # @param [Geom::Transformation] su_total_transformation The combined transformation of all parent sketchup objects
      # @param [IFC ENTITY] placement_parent The IFC entity that is the direct geometric parent in the sketchup model
      # @param [Hash<fcSpatialStructureElement>] spatial_structure Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
      # @param [Sketchup::Material] su_material The parent sketchup objects material which will be used when the given one does not have a directly associated material
      def initialize(
        ifc_model,
        su_instance,
        su_total_transformation,
        placement_parent = nil,
        instance_path = nil,
        spatial_structure = nil,
        su_material = nil,
        su_layer = nil
      )
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @instance_path = Sketchup::InstancePath.new(instance_path.to_a + [su_instance])
        @persistent_id_path = persistent_id_path(@instance_path)
        @spatial_structure = SpatialStructureHierarchy.new(@ifc_model, spatial_structure)
        @guid = IfcManager::IfcGloballyUniqueId.new(@ifc_model, @persistent_id_path)
        ent_type_name = su_instance.definition.get_attribute(
          'AppliedSchemaTypes',
          Settings.ifc_version
        )
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

      # Custom version of InstancePath.persistent_id_path
      #  that also works with only ComponentInstances without a face/edge leaf
      def persistent_id_path(instance_path)
        instance_path.to_a.map { |p| p.persistent_id.to_s }.join('.')
      end

      # Creates an IFC entity from a SketchUp instance based on the IFC classification in sketchup
      # and adds it to the IFC model.
      #
      # @param ent_type_name [String] The name of the IFC entity type to create.
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance to create the IFC entity from.
      # @param placement_parent [IfcObjectPlacement] The parent object placement for the IFC entity.
      # @param su_material [Sketchup::Material] The SketchUp material to apply to the IFC entity.
      # @param su_layer [Sketchup::Layer] The SketchUp layer to apply to the IFC entity.
      # @return [IfcEntity] The created IFC entity.
      def create_ifc_entity(ent_type_name, su_instance, placement_parent = nil, su_material = nil, su_layer = nil)
        su_definition = su_instance.definition

        # Strip any accidental direct Type assignments
        # @todo should be part of ifc_product_builder
        if ent_type_name && ent_type_name.end_with?('Type')
          case ent_type_name

          # Catch missing IfcAirTerminal in Ifc2x3
          when 'IfcAirTerminalType'
            ent_type_name = if Settings.ifc_version_compact == 'IFC2X3'
                              'IfcFlowTerminal'
                            else
                              'IfcAirTerminal'
                            end
          else
            ent_base_type_name = ent_type_name.delete_suffix('Type')
            ent_type_name = ent_base_type_name if @ifc.const_defined? ent_base_type_name
          end
        end

        # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecation in IFC 4
        ent_type_name = 'IfcWall' if ent_type_name == 'IfcWallStandardCase'

        entity_type = @ifc.const_get(ent_type_name) if ent_type_name
        if entity_type.nil?

          # If sketchup object is not an IFC entity it must become part of the parent object geometry
          ifc_entity = nil

        # Only a single IfcProject entity is allowed in an IFC model
        elsif entity_type == @ifc::IfcProject

          # @todo: set all correct parameters for IfcProject!!!
          # Enrich the base IfcProject with properties of the modelled IfcProject
          ifc_entity = IfcProjectBuilder.modify(@ifc_model, @ifc_model.project) do |modifier|
            modifier.set_global_id(@guid)
            modifier.set_name(su_definition.name) unless su_definition.name.empty?
            modifier.set_description(su_definition.description) unless su_definition.description.empty?
            modifier.set_attributes_from_su_instance(su_instance)
          end
          assign_entity_attributes(ifc_entity, placement_parent)
        else

          # (!)(?) check against list of valid IFC entities? IfcGroup, IfcProduct

          ifc_entity = entity_type.new(@ifc_model, su_instance)
          ifc_entity.globalid = @guid if entity_type < @ifc::IfcRoot

          # Set "tag" to component persistant_id like the other BIM Authoring Tools like Revit, Archicad and Tekla are doing
          # persistant_id in Sketchup is unique for the ComponentInstance placement, but not within the IFC model due to nested components
          # therefore the full persistent_id_path hierarchy is used
          ifc_entity.tag = Types::IfcLabel.new(@ifc_model, @persistent_id_path) if defined?(ifc_entity.tag)

          @spatial_structure.add(ifc_entity)
          assign_entity_attributes(ifc_entity, placement_parent)
        end
        create_geometry(su_definition, ifc_entity, placement_parent, su_material, su_layer)

        # We allways need a placement parent, so when the current entity is nil, we use the parent
        if ifc_entity
          placement_parent = ifc_entity
        end
        create_nested_objects(placement_parent, su_instance, su_material, su_layer)
      end

      # Assigns attributes to an IFC entity and adds it to a parent group if applicable.
      #
      # @param ifc_entity [Object] The IFC entity to assign attributes to.
      # @param placement_parent [Object] The parent group to add the entity to, if applicable.
      #
      # @return [void]
      def assign_entity_attributes(ifc_entity, placement_parent)
        # if parent is a IfcGroup, add entity to group
        if placement_parent.is_a?(@ifc::IfcGroup) && ifc_entity.is_a?(@ifc::IfcObjectDefinition)
          if placement_parent.is_a?(@ifc::IfcZone)
            placement_parent.add(ifc_entity) if ifc_entity.is_a?(@ifc::IfcZone) || ifc_entity.is_a?(@ifc::IfcSpace)
          else
            placement_parent.add(ifc_entity)
          end
        end

        return unless ifc_entity.is_a?(@ifc::IfcProduct)

        @spatial_structure.set_parent(ifc_entity)

        placement_rel_to = placement_parent.objectplacement if placement_parent.respond_to?(:objectplacement)
        @objectplacement = @ifc::IfcLocalPlacement.new(
          @ifc_model,
          @su_total_transformation,
          placement_rel_to
        )
        ifc_entity.objectplacement = @objectplacement

        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        #   could be better set from within IfcBuildingStorey?
        return unless ifc_entity.is_a?(@ifc::IfcBuildingStorey)

        elevation = @objectplacement.ifc_total_transformation.origin.z
        ifc_entity.elevation = Types::IfcLengthMeasure.new(@ifc_model, elevation)
      end

      # find nested objects (geometry and entities)
      #
      # @param placement_parent
      # @param su_instance
      # @param su_material
      # @return [Array<Sketchup::Face>] direct sketchup geometry
      def create_nested_objects(placement_parent, su_instance, su_material, su_layer)
        # (!)(?) Do we need to update su_material?
        # su_material = su_instance.material if su_instance.material

        component_instances = su_instance.definition.entities.select { |entity| entity.respond_to?(:definition) }
        component_instances.map do |component_instance|
          EntityBuilder.new(
            @ifc_model,
            component_instance,
            @su_total_transformation,
            placement_parent,
            @instance_path,
            @spatial_structure,
            su_material,
            su_layer
          )
        end
      end

      def create_geometry(definition, ifc_entity, placement_parent = nil, su_material, su_layer)
        definition_manager = @ifc_model.get_definition_manager(definition)

        # create geometry from faces
        # (!) skips any geometry placed inside objects NOT of the type IfcProduct
        return if definition_manager.faces.empty?

        case ifc_entity

        # IfcZone is a special kind of IfcGroup that can only include IfcSpace objects
        when @ifc::IfcZone
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'space geometry'
                            end
          sub_entity = @ifc_model.create_fallback_entity(
            @spatial_structure,
            definition_manager,
            @su_total_transformation,
            placement_parent,
            su_material,
            su_layer,
            sub_entity_name,
            'IfcSpace'
          )

          sub_entity.compositiontype = :element if sub_entity.respond_to?(:compositiontype=)
          sub_entity.interiororexteriorspace = :notdefined if sub_entity.respond_to?(:interiororexteriorspace=)

          # Add created space to the zone
          ifc_entity.add(sub_entity)

        when @ifc::IfcProject
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'project geometry'
                            end
          @ifc_model.create_fallback_entity(
            @spatial_structure,
            definition_manager,
            @su_total_transformation,
            placement_parent,
            su_material,
            su_layer,
            sub_entity_name
          )

        # An IfcGroup or IfcProject has no geometry so all Sketchup geometry is embedded in a IfcBuildingElementProxy
        #   IfcGroup is also the supertype of IfcSystem
        #   (?) mapped items?
        when @ifc::IfcGroup
          sub_entity_name = if ifc_entity.name
                              "#{ifc_entity.name.value} geometry"
                            else
                              'group geometry'
                            end
          sub_entity = @ifc_model.create_fallback_entity(
            @spatial_structure,
            definition_manager,
            @su_total_transformation,
            placement_parent,
            su_material,
            su_layer,
            sub_entity_name
          )
          ifc_entity.add(sub_entity)

        # When a Sketchup group/component is not classified as an IFC entity it should
        #   become part of the parent object geometry if the parent can have geometry
        when nil
          definition_manager = @ifc_model.get_definition_manager(definition)
          if placement_parent.respond_to?(:representation)
            parent_representation = placement_parent.representation

            if parent_representation
              transformation = placement_parent.objectplacement.ifc_total_transformation.inverse * @su_total_transformation

              definition_representation = definition_manager.get_definition_representation(
                transformation,
                su_material
              )

              # @todo: improve this
              mappedrepresentation = parent_representation.representations.first.items.first.mappingsource.mappedrepresentation
              mappedrepresentation.items += definition_representation.meshes

            else
              transformation = placement_parent.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
              add_representation(placement_parent,
                                 definition_manager,
                                 transformation,
                                 su_material,
                                 su_layer)
            end
          else
            # go up the placement hierarchy until a parent with a representation is found
            puts placement_parent.name
            puts definition_manager.name
            @ifc_model.create_fallback_entity(
              @spatial_structure,
              definition_manager,
              @su_total_transformation,
              placement_parent,
              su_material,
              su_layer
            )
          end
        else
          if ifc_entity.respond_to?(:representation)
            # calculate the local transformation
            # if the SU object if not an IfcProduct (cannot have a representation ), then BREP needs to be transformed with SU object transformation
            mesh_transformation = if ifc_entity.is_a?(@ifc::IfcProduct)
                                    @objectplacement.ifc_total_transformation.inverse * @su_total_transformation
                                  else
                                    @su_total_transformation
                                  end
            add_representation(ifc_entity,
                               definition_manager,
                               mesh_transformation,
                               su_material,
                               su_layer)
          else

            # @todo this creates empty objects for not supported entity types, catch at initialization
            @ifc_model.create_fallback_entity(
              @spatial_structure,
              definition_manager,
              @su_total_transformation,
              placement_parent,
              su_material,
              su_layer
            )
          end
        end
      end

      # Add representation to the IfcProduct, transform geometry with given transformation
      #
      # @param [IfcProduct] ifc_entity
      # @param [DefinitionManager] definition_manager
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @param [Sketchup::Layer] su_layer
      def add_representation(ifc_entity, definition_manager, transformation, su_material, su_layer)
        shape_representation = definition_manager.get_shape_representation(transformation, su_material, su_layer)
        if ifc_entity.representation
          ifc_entity.representation.representations.add(shape_representation)
        else
          ifc_entity.representation = IfcProductDefinitionShapeBuilder.build(@ifc_model) do |builder|
            builder.add_representation(shape_representation)
          end
        end
      end
    end
  end
end
