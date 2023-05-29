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

require_relative 'ifc_types'
require_relative 'IfcGloballyUniqueId'
require_relative 'entity_path'

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'layer_visibility')

    class ObjectCreator
      # This creator class creates the correct IFC entity for the given sketchup object and it's children
      #
      # @param [IfcManager::IfcModel] ifc_model The IFC model in which the new IFC entity must be added
      # @param [Sketchup::ComponentInstance, Sketchup::Group] su_instance The sketchup component instance or group for which an IFC entity must be created
      # @param [Geom::Transformation] su_total_transformation The combined transformation of all parent sketchup objects
      # @param [IFC ENTITY] placement_parent The IFC entity that is the direct geometric parent in the sketchup model
      # @param [Hash<fcSpatialStructureElement>] entity_path Hash with all parent IfcSpatialStructureElements above this one in the hierarchy
      # @param [Sketchup::Material] su_material The parent sketchup objects material which will be used when the given one does not have a directly associated material
      def initialize(
        ifc_model,
        su_instance,
        su_total_transformation,
        placement_parent = nil,
        instance_path = nil,
        entity_path = nil,
        su_material = nil,
        su_layer = nil
      )
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        instances = instance_path.to_a + [su_instance]
        @instance_path = Sketchup::InstancePath.new(instances)
        @persistent_id_path = persistent_id_path(@instance_path)
        @entity_path = EntityPath.new(@ifc_model, entity_path)
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

      # Create IFC entity based on the IFC classification in sketchup
      def create_ifc_entity(ent_type_name, su_instance, placement_parent = nil, su_material = nil, su_layer = nil)
        su_definition = su_instance.definition

        # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecation in IFC 4
        ent_type_name = 'IfcWall' if ent_type_name == 'IfcWallStandardCase'

        entity_type = Settings.ifc_module.const_get(ent_type_name) if ent_type_name
        if entity_type.nil?

          # If sketchup object is not an IFC entity it must become part of the parent object geometry
          create_geometry(su_definition, nil, placement_parent, su_material, su_layer)
          create_nested_objects(placement_parent, su_instance, su_material, su_layer)
        elsif entity_type == @ifc::IfcProject

          # @todo: set all correct parameters for IfcProject!!!
          @ifc_model.project.su_object = su_instance
          ifc_entity = @ifc_model.project
          ifc_entity.globalid = @guid

          # get properties from Sketchup object and add them to ifc object
          @name = IfcManager::Types::IfcLabel.new(@ifc_model, su_definition.name) unless su_definition.name.empty?
          unless su_definition.description.empty?
            @description = IfcManager::Types::IfcLabel.new(@ifc_model, su_definition.description)
          end
          construct_entity(ifc_entity, placement_parent)
          create_geometry(su_definition, ifc_entity, placement_parent, su_material, su_layer)
          create_nested_objects(ifc_entity, su_instance, su_material, su_layer)
        else

          # (!)(?) check against list of valid IFC entities? IfcGroup, IfcProduct

          ifc_entity = entity_type.new(@ifc_model, su_instance)
          ifc_entity.globalid = @guid if entity_type < @ifc::IfcRoot

          # Set "tag" to component persistant_id like the other BIM Authoring Tools like Revit, Archicad and Tekla are doing
          # persistant_id in Sketchup is unique for the ComponentInstance placement, but not within the IFC model due to nested components
          # therefore the full persistent_id_path hierarchy is used
          ifc_entity.tag = Types::IfcLabel.new(@ifc_model, @persistent_id_path) if defined?(ifc_entity.tag)

          @entity_path.add(ifc_entity)
          construct_entity(ifc_entity, placement_parent)
          create_geometry(su_definition, ifc_entity, placement_parent, su_material, su_layer)
          create_nested_objects(ifc_entity, su_instance, su_material, su_layer)
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
            ifc_entity.elevation = Types::IfcLengthMeasure.new(@ifc_model, elevation)
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
        # (!)(?) Do we need to update su_material?
        # su_material = su_instance.material if su_instance.material

        component_instances = su_instance.definition.entities.select { |entity| entity.respond_to?(:definition) }
        component_instances.map do |component_instance|
          ObjectCreator.new(@ifc_model,
                            component_instance,
                            @su_total_transformation,
                            ifc_entity,
                            @instance_path,
                            @entity_path,
                            su_material,
                            su_layer)
        end
      end

      def create_geometry(definition, ifc_entity, placement_parent = nil, su_material, su_layer)
        definition_manager = @ifc_model.get_definition_manager(definition)

        # calculate the local transformation
        # if the SU object if not an IfcProduct (cannot have a representation ), then BREP needs to be transformed with SU object transformation
        brep_transformation = if ifc_entity.is_a?(@ifc::IfcProduct)
                                ifc_entity.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
                              else
                                @su_total_transformation
                              end

        # create geometry from faces
        # (!) skips any geometry placed inside objects NOT of the type IfcProduct
        unless definition_manager.faces.empty?
          case ifc_entity

          # IfcZone is a special kind of IfcGroup that can only include IfcSpace objects
          when @ifc::IfcZone
            sub_entity_name = if ifc_entity.name
                                "#{ifc_entity.name.value} geometry"
                              else
                                'space geometry'
                              end
            sub_entity = create_fallback_entity(definition_manager,
                                                brep_transformation,
                                                su_material,
                                                su_layer,
                                                sub_entity_name,
                                                'IfcSpace')

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
            sub_entity = create_fallback_entity(definition_manager,
                                                brep_transformation,
                                                su_material,
                                                su_layer,
                                                sub_entity_name)
            ifc_entity.add(sub_entity)

          # An IfcGroup or IfcProject has no geometry so all Sketchup geometry is embedded in a IfcBuildingElementProxy
          #   IfcGroup is also the supertype of IfcSystem
          #   (?) mapped items?
          when @ifc::IfcGroup
            sub_entity_name = if ifc_entity.name
                                "#{ifc_entity.name.value} geometry"
                              else
                                'group geometry'
                              end
            sub_entity = create_fallback_entity(definition_manager,
                                                brep_transformation,
                                                su_material,
                                                su_layer,
                                                sub_entity_name)
            ifc_entity.add(sub_entity)

          # When a Sketchup group/component is not classified as an IFC entity it should
          #   become part of the parent object geometry if the parent can have geometry
          when nil
            definition_manager = @ifc_model.get_definition_manager(definition)
            # if placement_parent.su_object
            #   parent_definition_manager = @ifc_model.get_definition_manager(placement_parent.su_object.definition)
            if placement_parent.respond_to?(:representation) # && placement_parent.representation
              transformation = placement_parent.objectplacement.ifc_total_transformation.inverse * @su_total_transformation
              # add_representation(placement_parent, definition_manager, transformation, su_material, su_layer)

              definition_representation = definition_manager.get_definition_representation(transformation,
                                                                                           su_material)

              mappedrepresentation = placement_parent.representation.representations[0].items.mappingsource.mappedrepresentation
              mappedrepresentation.items += definition_representation.meshes

              # # add_representation(placement_parent,
              # #                    parent_definition_manager,
              # #                    transformation,
              # #                    su_material,
              # #                    su_layer)

              # definition_representation = definition_manager.get_definition_representation(transformation,
              #                                                                              su_material)
              # brep = definition_representation.faceted_brep
              # if brep
              #   # placement_parent.representation.representations[0].items.mappingsource.mappedrepresentation.items.add(brep)
              #   puts 'placement_parent'
              #   # puts parent_definition_manager
              #   # reps = parent_definition_manager.representations
              #   # reps[reps.keys.first]
              #   parent_definition_manager.representations.values.first.add_faceted_brep(brep)
              #   puts parent_definition_manager.representations.values.first.faceted_breps.length
              #   # parent_definition_manager.representations.first.first.add_faceted_brep(brep) # HACK!!!

              #   # puts placement_parent
              # end
              # # definition_representation.add_faceted_brep(faces, su_material, transformation)

            else
              create_fallback_entity(definition_manager, brep_transformation, su_material, su_layer)
            end
            # else
            #   create_fallback_entity(definition_manager, brep_transformation, su_material, su_layer)
            # end
          else
            if ifc_entity.respond_to?(:representation)
              add_representation(ifc_entity,
                                 definition_manager,
                                 brep_transformation,
                                 su_material,
                                 su_layer)
            else

              # @todo this creates empty objects for not supported entity types, catch at initialization
              create_fallback_entity(definition_manager, brep_transformation, su_material, su_layer)
            end
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
        # if ifc_entity.representation
        #   puts ifc_entity.representation.representations.first.items
        #   # shaperepresentation = get_definition_representation(transformation, su_material).ifc_shape_representation
        #   puts 'shaperepresentation'
        #   ifc_entity.representation.representations.first.items.first.mappingsource.mappedrepresentation.add_extra_representation(
        #     self, transformation, su_material
        #   )

        #   # # (?) new FacetedBrep here?
        #   # brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
        #   # representation_items = ifc_entity.representation.representations.first.items
        #   # if representation_items.first.respond_to? :mappingsource # IfcMappedItem
        #   #   representation_items.first.mappingsource.mappedrepresentation.items.add(brep)
        #   # else
        #   #   representation_items.add(brep)
        #   # end
        # else
        # ifc_entity.representation = definition_manager.create_product_definition_shape(transformation, su_material,
        #                                                                                su_layer)

        ##############################################
        # ifc_entity.representation wordt steeds overschreven!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        shape_representation = definition_manager.get_shape_representation(transformation, su_material, su_layer)
        if ifc_entity.representation
          ifc_entity.representation.representations.add(shape_representation)
        else
          ifc_entity.representation = IfcProductDefinitionShapeBuilder.build(@ifc_model) do |builder|
            builder.add_representation(shape_representation)
          end
        end
      end

      # Create IfcBuildingElementProxy (instead of unsupported IFC entities)
      #
      # @param definition_manager [IfcManager::DefinitionManager]
      # @param brep_transformation [Geom::Transformation]
      # @param su_material [Sketchup::Material]
      # @param su_layer [Sketchup::Layer]
      def create_fallback_entity(definition_manager,
                                 brep_transformation,
                                 su_material,
                                 su_layer,
                                 entity_name = nil,
                                 ent_type_name = 'IfcBuildingElementProxy')
        entity_type = Settings.ifc_module.const_get(ent_type_name)
        ifc_entity = entity_type.new(@ifc_model, nil)
        entity_name ||= definition_manager.name
        ifc_entity.name = Types::IfcLabel.new(@ifc_model, entity_name)
        add_representation(ifc_entity,
                           definition_manager,
                           brep_transformation,
                           su_material,
                           su_layer)
        ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(
          @ifc_model, Geom::Transformation.new
        )

        # IFC 4
        ifc_entity.predefinedtype = :notdefined if ifc_entity.respond_to?(:predefinedtype=)

        # IFC 2x3
        ifc_entity.compositiontype = :element if ifc_entity.respond_to?(:compositiontype=)

        # Add to spatial hierarchy
        @entity_path.add(ifc_entity)
        @entity_path.set_parent(ifc_entity)

        # create materialassociation
        unless @ifc_model.materials.include?(su_material)
          @ifc_model.materials[su_material] = MaterialAndStyling.new(@ifc_model, su_material)
        end

        # add product to materialassociation
        @ifc_model.materials[su_material].add_to_material(ifc_entity)

        ifc_entity
      end
    end
  end
end
