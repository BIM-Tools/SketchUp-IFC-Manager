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
    # @param [Array] faces
    # @param [Sketchup::Transformation] transformation
    # @param [Sketchup::Material] su_material
    #
    # @return [BimTools::IFC2X3::IfcFacetedBrep]
    def get_representation(faces, transformation, material = nil)
      representation_string = transformation.to_a.to_s
      representation_string << material.name if material
      unless @representations.key?(representation_string)
        @representations[representation_string] =
          BimTools::IfcManager::Representation.new(@ifc_model, faces, transformation, material)
      end
      @representations[representation_string]
    end
  end

  class Representation
    attr_reader :brep, :shaperepresentation, :representationmap

    def initialize(ifc_model, faces, transformation, material)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @brep = @ifc::IfcFacetedBrep.new(ifc_model, faces, transformation)
      @shaperepresentation = @ifc::IfcShapeRepresentation.new(ifc_model, nil)
      @shaperepresentation.items.add(brep)
      @representationmap = @ifc::IfcRepresentationMap.new(ifc_model)
      @representationmap.mappingorigin = ifc_model.default_placement
      @representationmap.mappedrepresentation = @shaperepresentation

      # add color from su-object material, or a su_parent's
      @ifc::IfcStyledItem.new(ifc_model, brep, material) if ifc_model.options[:colors] && material
    end
  end
end
