# frozen_string_literal: true

#  IfcModel.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'ifc_geometric_representation_context_builder'
require_relative 'ifc_geometric_representation_sub_context_builder'
require_relative 'ifc_owner_history_builder'
require_relative 'ifc_product_definition_shape_builder'
require_relative 'ifc_project_builder'
require_relative 'ifc_shape_representation_builder'
require_relative 'geolocation_builder'
require_relative 'spatial_structure'
require_relative 'entity_builder'
require_relative 'definition_manager'
require_relative 'step/step_writer'
require_relative 'ifcx/ifcx_writer'
require_relative '../transformation_helper'

require_relative 'classifications'
module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'visibility_utils')

    # The IfcModel class represents an IFC model created from a SketchUp model.
    # It includes methods for converting SketchUp entities to IFC entities and writing them to a STEP file.
    class IfcModel
      include VisibilityUtils

      # (?) possible additional methods:
      # - get_ifc_objects(hash ifc->su)
      # - get_su_objects(hash su->ifc)
      # - add_su_object
      # - add_ifc_object

      attr_reader :owner_history, :representationcontext, :representation_sub_context_body, :layers, :materials,
                  :classifications, :classificationassociations, :groups, :product_types,
                  :property_enumerations, :su_model, :project, :ifc_objects, :ifc_module, :ifc_version, :ifc_format,
                  :project_data, :export_summary, :options, :su_entities, :units, :default_location,
                  :default_axis, :default_refdirection, :default_placement, :textures

      # Initializes a new IfcModel instance.
      # (?) could be enhanced to also accept other sketchup objects
      #
      # @param [Sketchup::Model] su_model The SketchUp model to base the IFC model on.
      # @param [Hash] options An optional hash of options for the IFC model.
      # @param [Array<Sketchup::Entity>] su_entities An optional list of SketchUp entities to export to the IFC model. If nil, all entities in the model are exported.
      def initialize(su_model, options = {})
        defaults = {
          ifc_entities: false, # include IFC entity types given in array, like ["IfcWindow", "IfcDoor"], false means all
          hidden: false, # include hidden sketchup objects
          attributes: [], #    include specific attribute dictionaries given in array as IfcPropertySets, like ['SU_DefinitionSet', 'SU_InstanceSet'], false means all
          classifications: true, #  add all SketchUp classifications
          layers: true, #  create IfcPresentationLayerAssignments
          materials: true, #  create IfcMaterials
          colors: true, #  create IfcStyledItems
          geometry: 'Brep', #  create geometry for entities
          fast_guid: false, # create simplified guids
          dynamic_attributes: true, #  export dynamic component data
          types: true, #  create IfcTypeProducts
          # open_file: false, # open created file in given/default application
          classification_suffix: true, #  add classification suffix to entity names
          model_axes: false,
          base_quantities: true, # Export IFC base quantities for certain IFC entities
          textures: false, # Export textures
          double_sided_faces: false, # Export double sided faces
          export_entities: [], # Export only the given entities
          root_entities: [] # Export only the given entities and their children
        }
        @options = defaults.merge(options)

        creation_date = Time.now

        su_model.set_attribute('IfcManager', 'description', '')
        @project_data = su_model.attribute_dictionaries['IfcManager']

        @ifc_module = Settings.ifc_module
        @ifc_version = Settings.ifc_version
        @ifc_format = :step
        @su_model = su_model
        @su_entities = @options[:export_entities]
        @ifc_id = 0
        @export_summary = {}

        # create collections for materials and layers
        @materials = {}
        @layers = {}
        @groups = {}
        @classifications = IfcManager::Classifications.new(self)

        # Enable texture export if textures option is enabled and the active IFC version is capable of exporting textures
        # We cannot use TextureWriter for writing textures because it only loads textures from objects, not materials directly.
        # but we do need it to get UV coordinates for textures.
        if @options[:textures] && @ifc_module.const_defined?(:IfcTextureMap) && @ifc_module::IfcTextureMap.method_defined?(:maps)
          @textures = Sketchup.create_texture_writer
        end

        # create empty array that will contain all IFC objects
        @ifc_objects = []

        # create object that keeps track of all different shaperepresentations for
        #   the different sketchup component definitions
        @definition_manager = collect_component_definitions(@su_model).to_h

        # create a hash with all Sketchup ComponentDefinitions and their IfcProductType counterparts
        @product_types = {}

        # Re use property enumerations when possible
        @property_enumerations = {}

        # create IfcOwnerHistory for all IFC objects
        @owner_history = IfcOwnerHistoryBuilder.build(self) do |builder|
          builder.owning_user_from_model(su_model)
          builder.owning_application(VERSION, 'IFC manager for sketchup', 'su_ifcmanager')
          builder.change_action = '.ADDED.'
          builder.last_modified_date = creation_date
          builder.creation_date = creation_date
        end

        # Set root transformation as base for all other transformations
        world_transformation = if @options[:model_axes]
                                 su_model.axes.transformation.inverse
                               else
                                 Geom::Transformation.new
                               end

        # Create default origin and axes for re-use throughout the model
        @default_placement = @ifc_module::IfcAxis2Placement3D.new(self, Geom::Transformation.new)
        @default_location = @default_placement.location
        @default_axis = @default_placement.axis
        @default_refdirection = @default_placement.refdirection

        # create IfcGeometricRepresentationContext for all IFC geometry objects
        @representationcontext = IfcGeometricRepresentationContextBuilder.build(self) do |builder|
          builder
            .set_context_type('Model')
            .set_world_coordinate_system
        end

        @representation_sub_context_body = IfcGeometricRepresentationSubContextBuilder.build(self) do |builder|
          builder
            .set_context_identifier('Body')
            .set_context_type('Model')
            .set_parent_context(@representationcontext)
            .set_target_view('model_view')
        end

        # create new IfcProject
        @project = IfcProjectBuilder.build(self) do |builder|
          builder.set_global_id
          builder.set_name(@su_model.name) unless @su_model.name.empty?
          builder.set_description(@su_model.description) unless @su_model.description.empty?
          builder.set_representationcontexts([@representationcontext])
        end

        # set_units
        @units = @project.unitsincontext

        # Add georeference
        GeolocationBuilder.new(self).setup_geolocation(world_transformation.inverse) if @options[:georeference]

        # When no entities are given for export, pass all model entities to create ifc objects
        # if nested_entities option is false, pass all model entities to create ifc objects to make sure they are all seperately checked
        if @options[:root_entities].empty?
          create_ifc_objects(su_model.entities, world_transformation)
        else
          create_ifc_objects(@options[:root_entities], world_transformation)
        end
      end

      # add object to ifc_objects array
      def add(ifc_object)
        @ifc_objects << ifc_object
        new_id
      end

      def new_id
        @ifc_id += 1
      end

      # write the IfcModel to given filepath
      # (?) could be enhanced to also accept multiple ifc types like step / ifczip / ifcxml / ifcJson / ifcx
      # (?) could be enhanced with export options hash
      def export(file_path)
        ext = File.extname(file_path).downcase
        @ifc_format = ext == '.ifcx' ? :ifcx : :step
        case @ifc_format
        when :ifcx
          ifcx_writer = IfcXWriter.new(self)
          ifcx_writer.write(file_path)
        else
          step_writer = IfcStepWriter.new(self)
          step_writer.write(file_path)
        end
      end

      # add object class name to export summary
      def summary_add(class_name)
        if @export_summary[class_name]
          @export_summary[class_name] += 1
        else
          @export_summary[class_name] = 1
        end
      end

      # Recursively create IFC objects for all given SketchUp entities and add those to the model
      #
      # @param [Sketchup::Entities] entities
      def create_ifc_objects(entities, transformation)
        faces = []
        instance_path = Sketchup::InstancePath.new([])
        spatial_structure = SpatialStructureHierarchy.new(self)
        spatial_structure.add(@project)

        entities.each do |entity|
          # Skip hidden objects if skip-hidden option is set
          next unless instance_visible?(entity, @options)

          case entity
          when Sketchup::Group, Sketchup::ComponentInstance
            EntityBuilder.new(self, entity, transformation, @project, instance_path, spatial_structure)
          when Sketchup::Face
            faces << entity
          end
        end

        # Create a single IfcBuildingelementProxy from all unassociated faces in the model
        return if faces.empty?

        create_fallback_entity(
          spatial_structure,
          DefinitionManager.new(self, @su_model),
          Geom::Transformation.new,
          nil,
          nil,
          'model_geometry'
        )
      end

      def collect_component_definitions(su_model)
        su_model.definitions
                .select { |definition| definition.instances.any? }
                .map do |definition|
          [definition, DefinitionManager.new(self, definition)]
        end
      end

      def get_definition_manager(definition)
        @definition_manager[definition]
      end

      def get_styling(su_material, side = :both)
        materials[su_material] = IfcManager::MaterialAndStyling.new(self, su_material) unless materials[su_material]
        materials[su_material].get_styling(side)
      end

      # Create IfcBuildingElementProxy (instead of unsupported IFC entities)
      #
      # @param definition_manager [IfcManager::DefinitionManager]
      # @param mesh_transformation [Geom::Transformation]
      # @param su_material [Sketchup::Material]
      # @param su_layer [Sketchup::Layer]
      def create_fallback_entity(
        spatial_structure,
        definition_manager,
        total_transformation = nil,
        su_material = nil,
        su_layer = nil,
        entity_name = nil,
        ent_type_name = 'IfcBuildingElementProxy',
        geometry_type = nil
      )

        entity_type = @ifc_module.const_get(ent_type_name)
        ifc_entity = entity_type.new(self, nil, total_transformation)
        entity_name ||= definition_manager.name
        ifc_entity.name = Types::IfcLabel.new(self, entity_name)
        spatial_structure.add(ifc_entity)

        spatial_parent = ifc_entity.parent

        transformation = total_transformation * spatial_parent.objectplacement.ifc_total_transformation.inverse
        rotation_and_translation, scaling = TransformationHelper.decompose_transformation(transformation)

        ifc_entity.objectplacement = @ifc_module::IfcLocalPlacement.new(
          self,
          rotation_and_translation,
          spatial_parent.objectplacement
        )
        ifc_entity.objectplacement.places_object = ifc_entity

        add_representation(
          ifc_entity,
          definition_manager,
          scaling,
          su_material,
          su_layer,
          geometry_type
        )

        # IFC 4
        ifc_entity.predefinedtype = :notdefined if ifc_entity.respond_to?(:predefinedtype=)

        # IFC 2x3
        ifc_entity.compositiontype = :element if ifc_entity.respond_to?(:compositiontype=)

        # Add to spatial hierarchy
        spatial_structure.add(ifc_entity)
        # spatial_structure.set_parent(ifc_entity)

        # create materialassociation
        materials[su_material] = MaterialAndStyling.new(self, su_material) unless materials.include?(su_material)

        # add product to materialassociation
        materials[su_material].add_to_material(ifc_entity)

        ifc_entity
      end

      # Add representation to the IfcProduct, transform geometry with given transformation
      #
      # @param [IfcProduct] ifc_entity
      # @param [DefinitionManager] definition_manager
      # @param [Sketchup::Transformation] transformation
      # @param [Sketchup::Material] su_material
      # @param [Sketchup::Layer] su_layer
      def add_representation(ifc_entity, definition_manager, transformation, su_material, su_layer, geometry_type = nil)
        shape_representation = definition_manager.get_shape_representation(
          transformation,
          su_material,
          su_layer,
          geometry_type,
          ifc_entity
        )
        if ifc_entity.representation
          ifc_entity.representation.representations.add(shape_representation)
        else
          ifc_entity.representation = IfcProductDefinitionShapeBuilder.build(self) do |builder|
            builder.add_representation(shape_representation)
          end
        end
      end
    end
  end
end
