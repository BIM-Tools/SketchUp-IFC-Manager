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
require_relative 'ifc_shape_representation_builder'
require_relative 'entity_path'
require_relative 'ObjectCreator'
require_relative 'representation_manager'
require_relative 'step_writer'

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
      attr_reader :su_model, :project, :ifc_objects, :export_summary, :options, :su_entities, :units,
                  :default_location, :default_axis, :default_refdirection, :default_placement, :representation_manager

      # creates an IFC model based on given su model
      # (?) could be enhanced to also accept other sketchup objects

      # Creates an IFC model based on given su model
      #
      # @param su_model [Sketchup::Model]
      # @param options [Hash] Optional options hash
      # @param su_entities [Array<Sketchup::Entity>] Optional list of entities that have to be exported to IFC, nil exports all model entities.
      def initialize(su_model, options = {})
        defaults = {
          ifc_entities: false, # include IFC entity types given in array, like ["IfcWindow", "IfcDoor"], false means all
          hidden: false, # include hidden sketchup objects
          attributes: [], #    include specific attribute dictionaries given in array as IfcPropertySets, like ['SU_DefinitionSet', 'SU_InstanceSet'], false means all
          classifications: true, #  add all SketchUp classifications
          layers: true, #  create IfcPresentationLayerAssignments
          materials: true, #  create IfcMaterials
          colors: true, #  create IfcStyledItems
          geometry: true, #  create geometry for entities
          fast_guid: false, # create simplified guids
          dynamic_attributes: true, #  export dynamic component data
          types: true,
          mapped_items: true, # export component definitions as mapped items
          export_entities: [],
          root_entities: []
        }
        @options = defaults.merge(options)

        @ifc = Settings.ifc_module
        @su_model = su_model
        @su_entities = @options[:export_entities]
        @ifc_id = 0
        @export_summary = {}

        # create collections for materials and layers
        @materials = {}
        @layers = {}
        @classifications = IfcManager::Classifications.new(self)

        # create empty array that will contain all IFC objects
        @ifc_objects = []

        # create object that keeps track of all different shaperepresentations for
        #   the different sketchup component definitions
        @representation_manager = RepresentationManager.new(self)

        # # create empty hash that will contain all Mapped Representations (Component Definitions)
        # @mapped_representations = {}

        # Re use property enumerations when possible
        @property_enumerations = {}

        # create IfcOwnerHistory for all IFC objects
        @owner_history = create_ownerhistory

        # create new IfcProject
        @project = @ifc::IfcProject.new(self, su_model)

        # set_units
        @units = @project.unitsincontext

        # create IfcGeometricRepresentationContext for all IFC geometry objects
        @representationcontext = create_representationcontext

        @project.representationcontexts = Types::Set.new([@representationcontext])

        # Create default origin and axes for re-use throughout the model
        transformation = Geom::Transformation.new
        @default_placement = @ifc::IfcAxis2Placement3D.new(self, transformation)
        @default_location = @default_placement.location
        @default_axis = @default_placement.axis
        @default_refdirection = @default_placement.refdirection

        # create a hash with all Sketchup ComponentDefinitions and their IfcProductType counterparts
        @product_types = {}

        # When no entities are given for export, pass all model entities to create ifc objects
        # if nested_entities option is false, pass all model entities to create ifc objects to make sure they are all seperately checked
        if @options[:root_entities].empty?
          create_ifc_objects(su_model.entities)
        else
          create_ifc_objects(@options[:root_entities])
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
        IfcManager::IfcStepWriter.new(self, 'file_schema', 'file_description', file_path, @su_model)
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
      # @param entities [Sketchup::Entities]
      def create_ifc_objects(entities)
        faces = []
        entity_path = EntityPath.new(self)
        entity_path.add(@project)
        entitiy_count = entities.length
        i = 0
        while i < entitiy_count
          ent = entities[i]

          # skip hidden objects if skip-hidden option is set
          unless @options[:hidden] == false && (ent.hidden? || !IfcManager.layer_visible?(ent.layer))
            case ent
            when Sketchup::Group, Sketchup::ComponentInstance
              transformation = Geom::Transformation.new
              ObjectCreator.new(self, ent, transformation, @project, entity_path)
            when Sketchup::Face
              faces << ent
            end
          end
          i += 1
        end

        # create a single IfcBuildingelementProxy from all 'loose' faces in the model
        unless faces.empty?
          sub_entity_name = if @project.name
                              "#{@project.name.value} geometry"
                            else
                              'project geometry'
                            end
          shape_representation = IfcShapeRepresentationBuilder.build(self) do |builder|
            builder.set_contextofitems(self.representationcontext)
            builder.set_representationtype
            builder.add_item(@ifc::IfcFacetedBrep.new(self, faces, Geom::Transformation.new))
          end

          ifc_entity = @ifc::IfcBuildingElementProxy.new(self, nil)
          ifc_entity.name = Types::IfcLabel.new(self, sub_entity_name)
          ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(self, Geom::Transformation.new)
          ifc_entity.predefinedtype = :notdefined if ifc_entity.respond_to?(:predefinedtype=)
          ifc_entity.compositiontype = :element if ifc_entity.respond_to?(:compositiontype=)
          ifc_entity.representation = IfcProductDefinitionShapeBuilder.build(self) do |builder|
            builder.add_representation(shape_representation)
          end

          # Add to spatial hierarchy
          entity_path.add(ifc_entity)
          entity_path.set_parent(ifc_entity)
        end
      end
    end
  end
end
