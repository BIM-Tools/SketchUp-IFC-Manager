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
    require File.join(PLUGIN_PATH_LIB, 'visibility_utils')

    # The EntityBuilder class is responsible for creating the correct IFC entity
    # for a given SketchUp object and its children.
    class EntityBuilder
      include VisibilityUtils

      # Initializes a new instance of the EntityBuilder class.
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
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @instance_path = Sketchup::InstancePath.new(instance_path.to_a + [su_instance])
        @persistent_id_path = persistent_id_path(@instance_path)
        @spatial_structure = SpatialStructureHierarchy.new(@ifc_model, spatial_structure)
        @guid = IfcManager::IfcGloballyUniqueId.new(@ifc_model, @persistent_id_path)
        entity_type_name = su_instance.definition.get_attribute(
          'AppliedSchemaTypes',
          ifc_model.ifc_version
        )
        su_material = su_instance.material if su_instance.material
        su_layer = su_instance.layer if su_instance.layer.name != 'Layer0' || su_layer.nil?

        # Add the current sketchup object's transformation to the total transformation
        @su_total_transformation = su_total_transformation * su_instance.transformation

        # check if entity is one of the entities that need to be exported (and possibly it's nested entities)
        if @ifc_model.su_entities.empty?
          if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(entity_type_name)
            create_ifc_entity(entity_type_name, su_instance, placement_parent, su_material, su_layer)
          end
        elsif @ifc_model.su_entities.include?(su_instance)
          if @ifc_model.options[:ifc_entities] == false || @ifc_model.options[:ifc_entities].include?(entity_type_name)
            create_ifc_entity(entity_type_name, su_instance, placement_parent, su_material, su_layer)
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
      def create_ifc_entity(entity_type_name, su_instance, placement_parent = nil, su_material = nil, su_layer = nil)
        su_definition = su_instance.definition

        entity_type_name = map_entity_type(entity_type_name)

        entity_type = @ifc_module.const_get(entity_type_name) if entity_type_name

        ifc_entity = determine_ifc_entity(entity_type, su_instance, placement_parent)

        create_geometry(su_definition, ifc_entity, placement_parent, su_material, su_layer)

        add_placement_parent_relationships(ifc_entity, placement_parent)

        # We always need a placement parent, so when the current entity is nil, we use the parent
        placement_parent = ifc_entity if ifc_entity
        create_nested_objects(placement_parent, su_instance, su_material, su_layer)
      end

      # Maps an entity type name to its correct version or base type.
      #
      # @param entity_type_name [String] The name of the entity type to be mapped.
      # @return [String] The mapped entity type name.
      def map_entity_type(entity_type_name)
        # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecation in IFC 4
        return 'IfcWall' if entity_type_name == 'IfcWallStandardCase'

        return entity_type_name unless entity_type_name && entity_type_name.end_with?('Type')

        # Strip any accidental direct Type assignments
        # @todo should be part of ifc_product_builder
        entity_base_name = entity_type_name.chomp('Type')

        case entity_base_name
        when 'IfcAirTerminal'
          # Catch missing IfcAirTerminal in Ifc2x3
          @ifc_model.ifc_version == 'IFC 2x3' ? 'IfcFlowTerminal' : 'IfcAirTerminal'
        when 'IfcPipeSegment'
          # Catch missing IfcPipeSegment in Ifc2x3
          @ifc_model.ifc_version == 'IFC 2x3' ? 'IfcFlowSegment' : 'IfcPipeSegment'
        else
          @ifc_module.const_defined?(entity_base_name) ? entity_base_name : entity_type_name
        end
      end

      # Determines the appropriate IFC entity based on the given entity type, SketchUp instance, and placement parent.
      #
      # @param entity_type [Class] The class representing the entity type.
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance.
      # @param placement_parent [Sketchup::Group, Sketchup::ComponentInstance] The placement parent.
      # @return [Class] The determined IFC entity class or the entity type class itself.
      def determine_ifc_entity(entity_type, su_instance, placement_parent)
        return handle_unclassified_component(su_instance, placement_parent) if entity_type.nil?
        return handle_ifc_project(su_instance, placement_parent) if entity_type == @ifc_module::IfcProject
        return create_ifc_product(entity_type, su_instance, placement_parent) if entity_type < @ifc_module::IfcProduct
        return create_ifc_group(entity_type, su_instance, placement_parent) if entity_type < @ifc_module::IfcGroup
        return create_ifc_root(entity_type, su_instance, placement_parent) if entity_type < @ifc_module::IfcRoot

        # Pass the entity type class to the geometry creation method to be caught appropriately
        entity_type
      end

      # Handles an unclassified component by determining its placement parent and creating a building element proxy if necessary.
      #
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance of the unclassified component.
      # @param placement_parent [IFC::IfcSpatialStructureElement] The placement parent of the unclassified component.
      # @return [IFC::IfcBuildingElementProxy, nil] The created building element proxy if the placement parent is an IfcSpatialStructureElement, otherwise nil.
      def handle_unclassified_component(su_instance, placement_parent)
        # Don't add unclassified components as direct geometry to spatial elements
        if placement_parent.is_a?(@ifc_module::IfcSpatialStructureElement)
          return create_building_element_proxy(su_instance, placement_parent)
        end

        # If sketchup object is not an IFC entity it must become part of the parent object geometry
        nil
      end

      # Modifies the IfcProject entity in the IFC model with the provided parameters.
      #
      # @param su_instance [Object] The SketchUp instance associated with the IfcProject.
      # @param placement_parent [Object] The parent entity for the placement of the IfcProject.
      # @return [Object] The modified IfcProject entity.
      def handle_ifc_project(su_instance, placement_parent)
        # Only a single IfcProject entity is allowed in an IFC model
        # @todo: set all correct parameters for IfcProject!!!
        # Enrich the base IfcProject with properties of the modelled IfcProject
        ifc_entity = IfcProjectBuilder.modify(@ifc_model, @ifc_model.project) do |modifier|
          modifier.set_global_id(@guid)
          modifier.set_name(su_definition.name) unless su_definition.name.empty?
          modifier.set_description(su_definition.description) unless su_definition.description.empty?
          modifier.set_attributes_from_su_instance(su_instance)
        end
        assign_entity_attributes(ifc_entity, placement_parent)
        ifc_entity
      end

      # Creates an IFC root entity of the specified type and assigns it to the given SketchUp instance and placement parent.
      #
      # @param entity_type [Class] The type of IFC entity to create.
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance to assign to the IFC entity.
      # @param placement_parent [IFC::IfcObjectPlacement] The placement parent for the IFC entity.
      # @return [IFC::IfcRoot] The created IFC root entity.
      def create_ifc_root(entity_type, su_instance, placement_parent)
        # (!)(?) check against list of valid IFC entities? IfcGroup, IfcProduct

        ifc_entity = entity_type.new(@ifc_model, su_instance)
        ifc_entity.globalid = @guid

        @spatial_structure.add(ifc_entity)
        assign_entity_attributes(ifc_entity, placement_parent)
        ifc_entity
      end

      # Creates an IFC group and assigns it to the given SketchUp instance.
      #
      # @param entity_type [Class] The type of IFC entity to create.
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance to assign to the IFC entity.
      # @param placement_parent [IFC::IfcObjectPlacement] The placement parent for the IFC entity.
      # @return [IFC::IfcGroup] The created IFC group.
      def create_ifc_group(entity_type, su_instance, placement_parent)
        group_name = su_instance.name unless su_instance.name.empty?
        group_name ||= su_instance.definition.name

        return @ifc_model.groups[group_name] if @ifc_model.groups.key?(group_name)

        ifc_entity = entity_type.new(@ifc_model, su_instance)
        ifc_entity.globalid = @guid

        @spatial_structure.add(ifc_entity)
        assign_entity_attributes(ifc_entity, placement_parent)

        @ifc_model.groups[group_name] = ifc_entity

        ifc_entity
      end

      def create_ifc_product(entity_type, su_instance, placement_parent)
        # (!)(?) check against list of valid IFC entities? IfcGroup, IfcProduct

        ifc_entity = entity_type.new(@ifc_model, su_instance, @su_total_transformation)
        ifc_entity.globalid = @guid

        # Set "tag" to component persistant_id like the other BIM Authoring Tools like Revit, Archicad and Tekla are doing
        # persistant_id in Sketchup is unique for the ComponentInstance placement, but not within the IFC model due to nested components
        # therefore the full persistent_id_path hierarchy is used
        ifc_entity.tag = Types::IfcLabel.new(@ifc_model, @persistent_id_path) if defined?(ifc_entity.tag)

        @spatial_structure.add(ifc_entity)
        assign_entity_attributes(ifc_entity, placement_parent)
        ifc_entity
      end

      # Creates a building element proxy in the IFC model based on a SketchUp instance.
      #
      # @param su_instance [Sketchup::ComponentInstance] The SketchUp instance to create the proxy from.
      # @param placement_parent [IFC::IfcObjectPlacement] The parent object placement for the proxy.
      # @return [IFC::IfcBuildingElementProxy] The created building element proxy.
      def create_building_element_proxy(su_instance, placement_parent)
        ifc_entity = @ifc_module::IfcBuildingElementProxy.new(@ifc_model, su_instance, @su_total_transformation)
        ifc_entity.globalid = @guid
        ifc_entity.tag = Types::IfcLabel.new(@ifc_model, @persistent_id_path)
        assign_entity_attributes(ifc_entity, placement_parent)
        ifc_entity
      end

      # Assigns attributes to an IFC entity and adds it to a parent group if applicable.
      #
      # @param ifc_entity [Object] The IFC entity to assign attributes to.
      # @param placement_parent [Object] The parent group to add the entity to, if applicable.
      #
      # @return [void]
      def assign_entity_attributes(ifc_entity, placement_parent)
        # if parent is a IfcGroup, add entity to group
        if placement_parent.is_a?(@ifc_module::IfcGroup) && ifc_entity.is_a?(@ifc_module::IfcObjectDefinition)
          if placement_parent.is_a?(@ifc_module::IfcZone)
            if ifc_entity.is_a?(@ifc_module::IfcZone) || ifc_entity.is_a?(@ifc_module::IfcSpace)
              placement_parent.add(ifc_entity)
            end
          else
            placement_parent.add(ifc_entity)
          end
        end

        return unless ifc_entity.is_a?(@ifc_module::IfcProduct)

        @spatial_structure.set_parent(ifc_entity)

        transformation = if placement_parent == @ifc_model.project
                           Geom::Transformation.new
                         else
                           @su_total_transformation
                         end

        placement_rel_to = placement_parent.objectplacement if placement_parent.respond_to?(:objectplacement)
        @objectplacement = @ifc_module::IfcLocalPlacement.new(
          @ifc_model,
          transformation,
          placement_rel_to
        )
        ifc_entity.objectplacement = @objectplacement

        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        #   could be better set from within IfcBuildingStorey?
        return unless ifc_entity.is_a?(@ifc_module::IfcBuildingStorey)

        return unless ['IFC 2x3', 'IFC 4'].include?(@ifc_model.ifc_version)

        elevation = @objectplacement.ifc_total_transformation.origin.z
        ifc_entity.elevation = Types::IfcLengthMeasure.new(@ifc_model, elevation)
        # ElevationOfFFLRelative
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

        su_child_instances(su_instance).map do |su_child_instance|
          create_entity_builder(placement_parent, su_child_instance, su_material, su_layer)
        end
      end

      # Retrieves the child instances of a given SketchUp instance that have a definition.
      #
      # @param su_instance [Sketchup::ComponentInstance, Sketchup::Group] The SketchUp component instance or group whose child instances are to be retrieved.
      #
      # @return [Array<Sketchup::ComponentInstance, Sketchup::Group>] Returns an array of child instances that have a definition.
      def su_child_instances(su_instance)
        su_instance.definition.entities.select { |entity| entity.respond_to?(:definition) }
      end

      # Creates a new EntityBuilder instance for a given SketchUp instance if it is visible.
      #
      # @param placement_parent [IfcEntity, nil] The IFC entity that is the direct geometric parent in the SketchUp model.
      # @param su_instance [Sketchup::ComponentInstance, Sketchup::Group] The SketchUp component instance or group for which an IFC entity must be created.
      # @param su_material [Sketchup::Material, nil] The parent SketchUp object's material which will be used when the given one does not have a directly associated material.
      # @param su_layer [Sketchup::Layer, nil] The SketchUp layer associated with the entity.
      #
      # @return [EntityBuilder, nil] Returns a new EntityBuilder instance if the SketchUp instance is visible, otherwise returns nil.
      def create_entity_builder(placement_parent, su_instance, su_material, su_layer)
        return unless instance_visible?(su_instance, @ifc_model.options)

        transformation = if placement_parent == @ifc_model.project
                           su_instance.transformation
                         else
                           @su_total_transformation
                         end

        EntityBuilder.new(
          @ifc_model,
          su_instance,
          transformation,
          placement_parent,
          @instance_path,
          @spatial_structure,
          su_material,
          su_layer
        )
      end

      def create_geometry(definition, ifc_entity, placement_parent = nil, su_material, su_layer)
        definition_manager = @ifc_model.get_definition_manager(definition)

        # create geometry from faces
        # (!) skips any geometry placed inside objects NOT of the type IfcProduct
        return if definition_manager.faces.empty?

        case ifc_entity

        when @ifc_module::IfcExtrudedAreaSolid.class
          add_representation_to_parent(placement_parent, definition_manager, su_material, su_layer, 'SweptSolid')

        # IfcZone is a special kind of IfcGroup that can only include IfcSpace objects
        when @ifc_module::IfcZone
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

        when @ifc_module::IfcProject
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
        when @ifc_module::IfcGroup
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
          add_representation_to_parent(placement_parent, definition_manager, su_material, su_layer)
        else
          if ifc_entity.respond_to?(:representation)
            # calculate the local transformation
            # if the SU object if not an IfcProduct (cannot have a representation ), then BREP needs to be transformed with SU object transformation
            mesh_transformation = if ifc_entity.is_a?(@ifc_module::IfcProduct)
                                    @objectplacement.ifc_total_transformation.inverse * @su_total_transformation
                                  else
                                    @su_total_transformation
                                  end
            add_representation(
              ifc_entity,
              definition_manager,
              mesh_transformation,
              su_material,
              su_layer
            )
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
      def add_representation(ifc_entity, definition_manager, transformation, su_material, su_layer, geometry_type = nil)
        # geometry_type = 'Brep' if ifc_entity.is_a?(@ifc_module::IfcSpace)
        shape_representation = definition_manager.get_shape_representation(
          transformation,
          su_material,
          su_layer,
          geometry_type
        )
        if ifc_entity.representation
          ifc_entity.representation.representations.add(shape_representation)
        else
          ifc_entity.representation = IfcProductDefinitionShapeBuilder.build(@ifc_model) do |builder|
            builder.add_representation(shape_representation)
          end
        end
      end

      # Adds representation to the parent entity.
      #
      # @param placement_parent [Object] The parent entity to which the representation will be added.
      # @param definition_manager [Object] The definition manager object.
      # @param su_material [Object] The SketchUp material object.
      # @param su_layer [Object] The SketchUp layer object.
      # @param geometry_type [Object, nil] The type of geometry.
      #
      # @return [void]
      def add_representation_to_parent(placement_parent, definition_manager, su_material, su_layer, geometry_type = nil)
        if placement_parent.respond_to?(:representation) # && !placement_parent.is_a?(@ifc_module::IfcSpatialStructureElement)
          parent_representation = placement_parent.representation

          # (?) Can this be improved by using the scaling component from IfcLocalPlacement_su?
          transformation = placement_parent.objectplacement.ifc_total_transformation.inverse * @su_total_transformation

          if parent_representation
            definition_representation = definition_manager.get_definition_representation(
              transformation,
              su_material
            )
            parent_representation.representations.first.items += definition_representation.meshes
          else
            add_representation(
              placement_parent,
              definition_manager,
              transformation,
              su_material,
              su_layer,
              geometry_type
            )
          end
        else
          # go up the placement hierarchy until a parent with a representation is found
          @ifc_model.create_fallback_entity(
            @spatial_structure,
            definition_manager,
            @su_total_transformation,
            placement_parent,
            su_material,
            su_layer,
            nil,
            'IfcBuildingElementProxy',
            geometry_type
          )
        end
      end

      # Adds additional relationships between the given IFC entity and its placement parent.
      #
      # @param ifc_entity [Object] The IFC entity to which relationships will be added.
      # @param placement_parent [Object] The parent entity to which the IFC entity is related.
      # @return [void]
      def add_placement_parent_relationships(ifc_entity, placement_parent)
        return unless placement_parent
        return if ifc_entity == placement_parent

        if defined?(@ifc_module::IfcSurfaceFeature) &&
           defined?(@ifc_module::IfcRelAdheresToElement) &&
           ifc_entity.is_a?(@ifc_module::IfcSurfaceFeature) &&
           placement_parent.is_a?(@ifc_module::IfcProduct) # TODO: should be IfcElement
          placement_parent.add_surface_feature(ifc_entity)
        end
      end
    end
  end
end
