# frozen_string_literal: true

#  material_and_styling.rb
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

module BimTools
  module IfcManager
    # Class that manages the relationship between a Sketchup material and
    #  it's IFC counterparts (material and styling)
    #
    # @param ifc_model [IfcModel]
    # @param su_material [Sketchup::Material] Sketckup material for which IFC material and styles will be created
    class MaterialAndStyling
      def initialize(ifc_model, su_material = nil)
        @ifc_model = ifc_model
        @ifc = Settings.ifc_module
        material_name = if su_material
                          su_material.display_name
                        else
                          'Default'
                        end
        @material_assoc = create_material_assoc(material_name)
        @surface_styles = create_surface_styles(su_material)
      end

      # Creates IfcRelAssociatesMaterial
      #
      # @param material_name [string]
      # @return [IfcRelAssociatesMaterial] Material association
      def create_material_assoc(material_name)
        material_assoc = @ifc::IfcRelAssociatesMaterial.new(@ifc_model)
        material_assoc.relatingmaterial = @ifc::IfcMaterial.new(@ifc_model)
        material_assoc.relatingmaterial.name = Types::IfcLabel.new(@ifc_model, material_name)
        material_assoc.relatedobjects = Types::Set.new
        material_assoc
      end

      # Creates IfcRelAssociatesMaterial
      #
      # @param su_material [Sketchup::Material]
      # @return [Ifc_Set] Set of IFC surface styles
      def create_surface_styles(su_material)
        if su_material && @ifc_model.options[:colors]
          surfacestyle = @ifc::IfcSurfaceStyle.new(@ifc_model, su_material)
          surfacestylerendering = @ifc::IfcSurfaceStyleRendering.new(@ifc_model, su_material)
          colourrgb = @ifc::IfcColourRgb.new(@ifc_model, su_material)

          # Workaround for mandatory IfcPresentationStyleAssignment in IFC2x3
          if Settings.ifc_version == 'IFC 2x3'
            styleassignment = @ifc::IfcPresentationStyleAssignment.new(@ifc_model, su_material)
            styleassignment.styles = Types::Set.new([surfacestyle])
            surface_styles = Types::Set.new([styleassignment])
          else
            surface_styles = Types::Set.new([surfacestyle])
          end

          surfacestyle.side = :both
          surfacestyle.name = Types::IfcLabel.new(@ifc_model, su_material.name)
          surfacestyle.styles = Types::Set.new([surfacestylerendering])

          surfacestylerendering.surfacecolour = colourrgb
          surfacestylerendering.reflectancemethod = :notdefined

          if su_material

            # add transparency, converted from Sketchup's alpha value
            surfacestylerendering.transparency = Types::IfcNormalisedRatioMeasure.new(@ifc_model, 1 - su_material.alpha)

            # add color values, converted from 0/255 to fraction
            colourrgb.red = Types::IfcNormalisedRatioMeasure.new(@ifc_model, su_material.color.red.to_f / 255)
            colourrgb.green = Types::IfcNormalisedRatioMeasure.new(@ifc_model, su_material.color.green.to_f / 255)
            colourrgb.blue = Types::IfcNormalisedRatioMeasure.new(@ifc_model, su_material.color.blue.to_f / 255)
          else

            # (?) use default values == white
            surfacestylerendering.transparency = Types::IfcNormalisedRatioMeasure.new(@ifc_model, 0.0)
            colourrgb.red = Types::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
            colourrgb.green = Types::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
            colourrgb.blue = Types::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
          end
          surface_styles
        end
      end

      # Add the material to an IFC entity
      #
      # @param ifc_entity [IfcProduct] IFC Entity
      def add_to_material(ifc_entity)
        @material_assoc.relatedobjects.add(ifc_entity)
      end

      # Add the stylings to a shaperepresentation
      #
      # @param ifc_entity [IfcShapeRepresentation] IFC Entity
      def add_to_styling(ifc_entity)
        if @surface_styles
          styled_item = @ifc::IfcStyledItem.new(@ifc_model, ifc_entity)
          styled_item.styles = @surface_styles
        end
      end
    end
  end
end
