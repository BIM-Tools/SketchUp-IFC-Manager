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
require_relative 'ifc_product_definition_shape_builder'
require_relative 'ifc_project_builder'
require_relative 'ifc_shape_representation_builder'
require_relative 'spatial_structure'
require_relative 'entity_builder'
require_relative 'definition_manager'
require_relative 'step_writer'
require_relative '../transformation_helper'

require_relative 'classifications'
module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'layer_visibility')

    class IfcModel
      # (?) possible additional methods:
      # - get_ifc_objects(hash ifc->su)
      # - get_su_objects(hash su->ifc)
      # - add_su_object
      # - add_ifc_object

      attr_accessor :owner_history, :representationcontext, :layers, :materials, :classifications,
                    :classificationassociations, :product_types, :property_enumerations
      attr_reader :su_model, :project, :ifc_objects, :project_data, :export_summary, :options, :su_entities, :units,
                  :default_location, :default_axis, :default_refdirection, :default_placement, :textures

      # creates an IFC model based on given su model
      # (?) could be enhanced to also accept other sketchup objects

      # Creates an IFC model based on given su model
      #
      # @param [Sketchup::Model] su_model
      # @param [Hash] options optional options hash
      # @param [Array<Sketchup::Entity>] su_entities optional list of entities that have to be exported to IFC, nil exports all model entities.
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
          types: true,
          mapped_items: true, # export component definitions as mapped items
          textures: false, # export component definitions as mapped items
          export_entities: [],
          root_entities: [],
          model_axes: false
        }
        @options = defaults.merge(options)

        su_model.set_attribute('IfcManager', 'description', '')
        @project_data = su_model.attribute_dictionaries['IfcManager']

        @ifc = Settings.ifc_module
        @su_model = su_model
        @su_entities = @options[:export_entities]
        @ifc_id = 0
        @export_summary = {}

        # create collections for materials and layers
        @materials = {}
        @layers = {}
        @classifications = IfcManager::Classifications.new(self)

        # Enable texture export if textures option is enabled and the active IFC version is capable of exporting textures
        # We cannot use TextureWriter for writing textures because it only loads textures from objects, not materials directly.
        # but we do need it to get UV coordinates for textures.
        if @options[:textures] && @ifc.const_defined?(:IfcTextureMap) && @ifc::IfcTextureMap.method_defined?(:maps)
          @textures = Sketchup.create_texture_writer
        end

        # create empty array that will contain all IFC objects
        @ifc_objects = []

        # create object that keeps track of all different shaperepresentations for
        #   the different sketchup component definitions
        @definition_manager = collect_component_definitions(@su_model).to_h

        # # create empty hash that will contain all Mapped Representations (Component Definitions)
        # @mapped_representations = {}

        # Re use property enumerations when possible
        @property_enumerations = {}

        # create IfcOwnerHistory for all IFC objects
        @owner_history = create_ownerhistory

        # create IfcGeometricRepresentationContext for all IFC geometry objects
        @representationcontext = create_representationcontext

        # create new IfcProject
        @project = IfcProjectBuilder.build(self) do |builder|
          builder.set_global_id
          builder.set_name(@su_model.name) unless @su_model.name.empty?
          builder.set_description(@su_model.description) unless @su_model.description.empty?
          builder.set_representationcontexts([@representationcontext])
        end

        # set_units
        @units = @project.unitsincontext

        # Create default origin and axes for re-use throughout the model
        @default_placement = @ifc::IfcAxis2Placement3D.new(self, Geom::Transformation.new)
        @default_location = @default_placement.location
        @default_axis = @default_placement.axis
        @default_refdirection = @default_placement.refdirection

        # create a hash with all Sketchup ComponentDefinitions and their IfcProductType counterparts
        @product_types = {}

        # Set root transformation as base for all other transformations
        transformation = if @options[:model_axes]
                           su_model.axes.transformation.inverse
                         else
                           Geom::Transformation.new
                         end

        # When no entities are given for export, pass all model entities to create ifc objects
        # if nested_entities option is false, pass all model entities to create ifc objects to make sure they are all seperately checked
        if @options[:root_entities].empty?
          create_ifc_objects(su_model.entities, transformation)
        else
          create_ifc_objects(@options[:root_entities], transformation)
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
      # (?) could be enhanced to also accept multiple ifc types like step / ifczip / ifcxml
      # (?) could be enhanced with export options hash
      def export(file_path)
        step_writer = IfcStepWriter.new(self)
        step_writer.write(file_path)
      end

      # add object class name to export summary
      def summary_add(class_name)
        if @export_summary[class_name]
          @export_summary[class_name] += 1
        else
          @export_summary[class_name] = 1
        end
      end

      # Create new IfcOwnerHistory
      def create_ownerhistory
        creation_date = Time.now.to_i.to_s
        owner_history = @ifc::IfcOwnerHistory.new(self)
        owninguser = @ifc::IfcPersonAndOrganization.new(self)
        owninguser.theperson = @ifc::IfcPerson.new(self)
        owninguser.theperson.familyname = Types::IfcLabel.new(self, '')
        owninguser.theorganization = @ifc::IfcOrganization.new(self)
        owninguser.theorganization.name = Types::IfcLabel.new(self, '')
        # owninguser.theperson = @ifc::IfcPerson.new(self)
        # owninguser.theorganization = @ifc::IfcOrganization.new(self)
        owner_history.owninguser = owninguser
        owningapplication = @ifc::IfcApplication.new(self)
        applicationdeveloper = @ifc::IfcOrganization.new(self)
        applicationdeveloper.name = Types::IfcLabel.new(self, 'BIM-Tools')
        owningapplication.applicationdeveloper = applicationdeveloper
        owningapplication.version = Types::IfcLabel.new(self, VERSION)
        owningapplication.applicationfullname = Types::IfcLabel.new(self, 'IFC manager for sketchup')
        owningapplication.applicationidentifier = Types::IfcIdentifier.new(self, 'su_ifcmanager')
        owner_history.owningapplication = owningapplication
        owner_history.changeaction = '.ADDED.'
        owner_history.lastmodifieddate = creation_date
        owner_history.creationdate = creation_date
        owner_history.lastmodifyinguser = owninguser
        owner_history.lastmodifyingapplication = owningapplication
        owner_history
      end

      # Create new IfcGeometricRepresentationContext
      def create_representationcontext
        context = @ifc::IfcGeometricRepresentationContext.new(self)
        context.contexttype = Types::IfcLabel.new(self, 'Model')
        context.coordinatespacedimension = '3'
        context.worldcoordinatesystem = @ifc::IfcAxis2Placement2D.new(self)

        # Older Sketchup versions don't have Point2d and Vector2d
        if Geom.const_defined?(:Point2d)
          context.worldcoordinatesystem.location = @ifc::IfcCartesianPoint.new(self, Geom::Point2d.new(0, 0))
          context.truenorth = @ifc::IfcDirection.new(self, Geom::Vector2d.new(0, 1))
        else
          context.worldcoordinatesystem.location = @ifc::IfcCartesianPoint.new(self, Geom::Point3d.new(0, 0, 0))
          context.truenorth = @ifc::IfcDirection.new(self, Geom::Vector3d.new(0, 1, 0))
        end
        context
      end

      # Recursively create IFC objects for all given SketchUp entities and add those to the model
      #
      # @param [Sketchup::Entities] entities
      def create_ifc_objects(entities, transformation)
        faces = []
        instance_path = Sketchup::InstancePath.new([])
        spatial_structure = SpatialStructureHierarchy.new(self)
        spatial_structure.add(@project)
        entitiy_count = entities.length
        i = 0
        while i < entitiy_count
          ent = entities[i]

          # skip hidden objects if skip-hidden option is set
          unless @options[:hidden] == false && (ent.hidden? || !IfcManager.layer_visible?(ent.layer))
            case ent
            when Sketchup::Group, Sketchup::ComponentInstance
              EntityBuilder.new(self, ent, transformation, @project, instance_path, spatial_structure)
            when Sketchup::Face
              faces << ent
            end
          end
          i += 1
        end

        # create a single IfcBuildingelementProxy from all 'loose' faces in the model
        return if faces.empty?

        create_fallback_entity(
          spatial_structure,
          DefinitionManager.new(self, @su_model),
          Geom::Transformation.new,
          nil, # placement_parent???
          nil,
          nil,
          'model_geometry'
        )
      end

      def collect_component_definitions(su_model)
        su_model.definitions.map do |definition|
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
        placement_parent = nil,
        su_material = nil,
        su_layer = nil,
        entity_name = nil,
        ent_type_name = 'IfcBuildingElementProxy'
      )

        entity_type = @ifc.const_get(ent_type_name)
        ifc_entity = entity_type.new(self, nil)
        entity_name ||= definition_manager.name
        ifc_entity.name = Types::IfcLabel.new(self, entity_name)
        spatial_structure.add(ifc_entity)

        # (?) Do we need this? Shouldn't placement_parent always be of type IfcSpatialStructureElement at this point?
        # The only case is that placement_parent is of type IfcProject, can't we prevent that from happening?
        # Can it actually be nil?
        placement_parent = spatial_structure.get_placement_parent(placement_parent)

        transformation = total_transformation * placement_parent.objectplacement.ifc_total_transformation.inverse
        rotation_and_translation, scaling = TransformationHelper.decompose_transformation(transformation)

        ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(
          self,
          rotation_and_translation,
          placement_parent.objectplacement
        )

        add_representation(
          ifc_entity,
          definition_manager,
          scaling,
          su_material,
          su_layer
        )

        # IFC 4
        ifc_entity.predefinedtype = :notdefined if ifc_entity.respond_to?(:predefinedtype=)

        # IFC 2x3
        ifc_entity.compositiontype = :element if ifc_entity.respond_to?(:compositiontype=)

        # Add to spatial hierarchy
        spatial_structure.add(ifc_entity)
        spatial_structure.set_parent(ifc_entity)

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
      def add_representation(ifc_entity, definition_manager, transformation, su_material, su_layer)
        shape_representation = definition_manager.get_shape_representation(transformation, su_material, su_layer)
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
