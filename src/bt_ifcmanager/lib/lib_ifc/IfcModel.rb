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

require_relative('IfcLabel')
require_relative('IfcIdentifier')
require_relative('entity_path')
require_relative('ObjectCreator')
require_relative 'representation_manager'
require_relative('step_writer')

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'layer_visibility.rb')

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
      # @parameter su_model [Sketchup::Model]
      # @parameter options [Hash] Optional options hash
      # @parameter su_entities [Array<Sketchup::Entity>] Optional list of entities that have to be exported to IFC, nil exports all model entities.
      #
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

        @ifc = BimTools::IfcManager::Settings.ifc_module
        @su_model = su_model
        @su_entities = @options[:export_entities]
        @ifc_id = 0
        @export_summary = {}

        # create collections for materials and layers
        @materials = {}
        @layers = {}
        @classifications = {}

        # create empty array that will contain all IFC objects
        @ifc_objects = []

        # create object that keeps track of all different shaperepresentations for
        #   the different sketchup component definitions
        @representation_manager = BimTools::IfcManager::RepresentationManager.new(self)

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

        @project.representationcontexts = IfcManager::Ifc_Set.new([@representationcontext])

        # Create default origin and axes for re-use throughout the model
        transformation = Geom::Transformation.new
        @default_placement = @ifc::IfcAxis2Placement3D.new(self, transformation)
        @default_location = @default_placement.location
        @default_axis = @default_placement.axis
        @default_refdirection = @default_placement.refdirection

        # create IfcProductTypes for all ComponentDefintions
        @product_types = get_product_types(@su_model)

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
        IfcStepWriter.new(self, 'file_schema', 'file_description', file_path, @su_model)
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
        owninguser.theperson.familyname = BimTools::IfcManager::IfcLabel.new(@ifc_model, '')
        owninguser.theorganization = @ifc::IfcOrganization.new(self)
        owninguser.theorganization.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, '')
        # owninguser.theperson = @ifc::IfcPerson.new(self)
        # owninguser.theorganization = @ifc::IfcOrganization.new(self)
        owner_history.owninguser = owninguser
        owningapplication = @ifc::IfcApplication.new(self)
        applicationdeveloper = @ifc::IfcOrganization.new(self)
        applicationdeveloper.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, 'BIM-Tools')
        owningapplication.applicationdeveloper = applicationdeveloper
        owningapplication.version = BimTools::IfcManager::IfcLabel.new(@ifc_model, VERSION)
        owningapplication.applicationfullname = BimTools::IfcManager::IfcLabel.new(@ifc_model,
                                                                                   'IFC manager for sketchup')
        owningapplication.applicationidentifier = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, 'su_ifcmanager')
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
        representationcontext = @ifc::IfcGeometricRepresentationContext.new(self)
        representationcontext.contexttype = BimTools::IfcManager::IfcLabel.new(@ifc_model, 'Model')
        representationcontext.coordinatespacedimension = '3'
        representationcontext.worldcoordinatesystem = @ifc::IfcAxis2Placement2D.new(self)
        representationcontext.worldcoordinatesystem.location = @ifc::IfcCartesianPoint.new(self, Geom::Point2d.new(0, 0))
        representationcontext.truenorth = @ifc::IfcDirection.new(self, Geom::Vector2d.new(0, 1))
        representationcontext
      end

      # create a hash with all Sketchup ComponentDefinitions and their IfcProductType counterparts
      def get_product_types(su_model)
        product_types = {}

        # Check if export option for types is set
        if @options[:types]
          definitions = su_model.definitions
          definitions.each do |definition|
            next unless definition.count_used_instances > 0

            ent_type_name = definition.get_attribute('AppliedSchemaTypes', BimTools::IfcManager::Settings.ifc_version)
            next unless ent_type_name

            # Replace IfcWallStandardCase by IfcWall, due to geometry issues and deprecated in IFC 4
            ent_type_name = 'IfcWall' if ent_type_name == 'IfcWallStandardCase'

            unless BimTools::IfcManager::Settings.ifc_module.const_defined?(ent_type_name) && BimTools::IfcManager::Settings.ifc_module.const_defined?(ent_type_name + 'Type')
              next
            end

            product = BimTools::IfcManager::Settings.ifc_module.const_get(ent_type_name)
            type_product = BimTools::IfcManager::Settings.ifc_module.const_get(ent_type_name + 'Type')
            product_types[definition] = type_product.new(self, definition, product)
          end
        end
        product_types
      end

      # Recursively create IFC objects for all given SketchUp entities and add those to the model
      #
      # @parameter entities [Sketchup::Entities]
      #
      def create_ifc_objects(entities)
        faces = []
        entity_path = EntityPath.new(self)
        entity_path.add(@project)
        entitiy_count = entities.length
        i = 0
        while i < entitiy_count
          ent = entities[i]

          # skip hidden objects if skip-hidden option is set
          unless @options[:hidden] == false && (ent.hidden? || !BimTools::IfcManager.layer_visible?(ent.layer))
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
          if @project.name
            sub_entity_name = "#{@project.name.value} geometry"
          else
            sub_entity_name = 'project geometry'
          end
          ifc_entity = @ifc::IfcBuildingElementProxy.new(self, nil)
          ifc_entity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, sub_entity_name)
          ifc_entity.representation = @ifc::IfcProductDefinitionShape.new(self, nil)
          brep = @ifc::IfcFacetedBrep.new(self, faces, Geom::Transformation.new)
          ifc_entity.representation.representations.first.items.add(brep)
          ifc_entity.objectplacement = @ifc::IfcLocalPlacement.new(self, Geom::Transformation.new)
          if ifc_entity.respond_to?(:predefinedtype=)
            ifc_entity.predefinedtype = :notdefined
          end
          if ifc_entity.respond_to?(:compositiontype=)
            ifc_entity.compositiontype = :element
          end

          # Add to spatial hierarchy
          entity_path.add(ifc_entity)
          entity_path.set_parent(ifc_entity)
        end
      end
    end
  end
end
