#  representation_manager.rb
#
#  Copyright 2021 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'material_and_styling'

module BimTools::IfcManager
  # Class that keeps track of all different shaperepresentations for
  #   the different sketchup component definitions
  class RepresentationManager
    def initialize(ifc_model)
      @ifc_model = ifc_model
      @definition_managers = {}
    end

    def get_definition_manager(definition)
      unless @definition_managers.key?(definition)
        @definition_managers[definition] = BimTools::IfcManager::DefinitionManager.new(@ifc_model, definition)
      end
      @definition_managers[definition]
    end
  end

  # Class that keeps track of all different shaperepresentations for
  #   a sketchup component definition
  class DefinitionManager
    attr_reader :definition

    def initialize(ifc_model, definition)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @ifc_model = ifc_model
      @definition = definition
      @representations = {}
    end

    # Get IFC representation for a component instance
    #   creates a new one when one does not yet exist for the definition
    #   with the given transformation otherwise returns the matching one
    #
    # (?) Faces are extracted for every instance of a component, it should
    #   be possible to only do that once for a component definition
    #
    # @param [Sketchup::ComponentDefinition] definition
    # @param [Array<Sketchup::Face>] faces
    # @param [Sketchup::Transformation] transformation
    # @param [Sketchup::Material] su_material
    # @return [BimTools::IFC2X3::IfcFacetedBrep]
    def get_representation(faces, transformation, material = nil)
      representation_string = transformation.to_a.to_s
      representation_string << material.name if material
      unless @representations.key?(representation_string)
        @representations[representation_string] =
          BimTools::IfcManager::ShapeRepresentation.new(@ifc_model, faces, transformation, material)
      end
      @representations[representation_string]
    end

    # Add representation to the IfcProduct, transform geometry with given transformation
    #
    # @param [Sketchup::Transformation] transformation
    def create_representation(faces, transformation, su_material)
      # definition = @su_object.definition

      # '@representation' is set to IfcLabel as default because the Sketchup attribute value is ''

      # set representation based on definition
      representation = @ifc::IfcProductDefinitionShape.new(@ifc_model, @definition)

      shape_representation = representation.representations.first

      # Check if Mapped representation should be used
      if shape_representation.representationtype.value == 'MappedRepresentation'
        mapped_item = @ifc::IfcMappedItem.new(@ifc_model)
        target = @ifc::IfcCartesianTransformationOperator3D.new(@ifc_model)
        target.localorigin = @ifc::IfcCartesianPoint.new(@ifc_model, Geom::Point3d.new)
        # definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
        definition_representation = get_representation(faces, transformation, su_material)
        mapped_item.mappingsource = definition_representation.representationmap
        mapped_item.mappingtarget = target
        shape_representation.items.add(mapped_item)
      else
        brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
        shape_representation.items.add(brep)

        # add color from su-object material, or a su_parent's
        if ifc_model.options[:colors] && su_material
          material_name = su_material.display_name
          
          # check if materialassociation exists
          unless ifc_model.materials[su_material]
            ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(ifc_model, su_material)
          end
          ifc_model.materials[su_material].add_to_styling(brep)
        end
      end

      # set layer
      if @ifc_model.options[:layers]

        # check if IfcPresentationLayerAssignment exists
        unless @ifc_model.layers[@definition.layer.name]

          # create new IfcPresentationLayerAssignment
          @ifc_model.layers[@definition.layer.name] =
            @ifc::IfcPresentationLayerAssignment.new(@ifc_model, @definition.layer)
        end

        # add self to IfcPresentationLayerAssignment
        @ifc_model.layers[@definition.layer.name].assigneditems.add(shape_representation)
      end
      representation
    end
  end

  class ShapeRepresentation
    attr_reader :brep, :shaperepresentation, :representationmap

    def initialize(ifc_model, faces, transformation, su_material)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @brep = @ifc::IfcFacetedBrep.new(ifc_model, faces, transformation)
      @shaperepresentation = @ifc::IfcShapeRepresentation.new(ifc_model, nil)
      @shaperepresentation.items.add(brep)
      @representationmap = @ifc::IfcRepresentationMap.new(ifc_model)
      @representationmap.mappingorigin = ifc_model.default_placement
      @representationmap.mappedrepresentation = @shaperepresentation

      # add color from su-object material, or a su_parent's
      if ifc_model.options[:colors] && su_material
        material_name = su_material.display_name
        
        # check if materialassociation exists
        unless ifc_model.materials[su_material]
          ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(ifc_model, su_material)
        end
        ifc_model.materials[su_material].add_to_styling(brep)
      end
    end
  end
end
