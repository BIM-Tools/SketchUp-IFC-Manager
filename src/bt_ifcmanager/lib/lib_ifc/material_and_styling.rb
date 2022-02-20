#  material_and_styling.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'IfcURIReference'

module BimTools
  module IfcManager
    # Class that manages the relationship between a Sketchup material and
    #  it's IFC counterparts (material and styling)
    #
    # @param ifc_model [BimTools::IfcManager::IfcModel]
    # @param su_material [Sketchup::Material] Sketckup material for which IFC material and styles will be created
    class MaterialAndStyling
      attr_reader :image_texture

      def initialize(ifc_model, su_material = nil)
        @ifc_model = ifc_model
        @su_material = su_material
        @ifc = BimTools::IfcManager::Settings.ifc_module
        @material_name = if su_material
                           su_material.display_name
                         else
                           'Default'
                         end
        @image_texture = create_image_texture
      end

      # Creates IfcRelAssociatesMaterial
      #
      # @param material_name [string]
      # @return [IfcRelAssociatesMaterial] Material association
      def create_material_assoc
        material_assoc = @ifc::IfcRelAssociatesMaterial.new(@ifc_model)
        material_assoc.relatingmaterial = @ifc::IfcMaterial.new(@ifc_model)
        material_assoc.relatingmaterial.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, @material_name)
        material_assoc.relatedobjects = IfcManager::Ifc_Set.new
        material_assoc
      end

      # Creates IfcRelAssociatesMaterial
      #
      # @param su_material [Sketchup::Material]
      # @return [Ifc_Set] Set of IFC surface styles
      def create_surface_styles
        if @su_material && @ifc_model.options[:colors]
          surfacestyle = @ifc::IfcSurfaceStyle.new(@ifc_model, @su_material)
          surfacestylerendering = @ifc::IfcSurfaceStyleRendering.new(@ifc_model, @su_material)
          colourrgb = @ifc::IfcColourRgb.new(@ifc_model, @su_material)

          # Workaround for mandatory IfcPresentationStyleAssignment in IFC2x3
          if BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'
            styleassignment = @ifc::IfcPresentationStyleAssignment.new(@ifc_model, @su_material)
            styleassignment.styles = IfcManager::Ifc_Set.new([surfacestyle])
            surface_styles = IfcManager::Ifc_Set.new([styleassignment])
          else
            surface_styles = IfcManager::Ifc_Set.new([surfacestyle])
          end

          surfacestyle.side = :both
          surfacestyle.styles = IfcManager::Ifc_Set.new([surfacestylerendering])

          surfacestylerendering.surfacecolour = colourrgb
          surfacestylerendering.reflectancemethod = :notdefined

          if @su_material

            # add transparency, converted from Sketchup's alpha value
            surfacestylerendering.transparency = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model,
                                                                                                     1 - @su_material.alpha)

            # add color values, converted from 0/255 to fraction
            colourrgb.red = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model,
                                                                                @su_material.color.red.to_f / 255)
            colourrgb.green = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model,
                                                                                  @su_material.color.green.to_f / 255)
            colourrgb.blue = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model,
                                                                                 @su_material.color.blue.to_f / 255)
          else

            # (?) use default values == white
            surfacestylerendering.transparency = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model, 0.0)
            colourrgb.red = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
            colourrgb.green = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
            colourrgb.blue = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(@ifc_model, 1.0)
          end
          surface_styles
        end
      end

      def create_image_texture
        if @ifc_model.textures && @su_material && su_texture = @su_material.texture
          image_texture = @ifc::IfcImageTexture.new(@ifc_model)
          image_texture.repeats = true
          image_texture.repeatt = true
          image_texture.urlreference = BimTools::IfcManager::IfcURIReference.new(@ifc_model, File.basename(su_texture.filename))
          image_texture
        end
      end

      # Add the material to an IFC entity
      #
      # @param ifc_entity [IfcProduct] IFC Entity
      def add_to_material(ifc_entity)
        @material_assoc ||= create_material_assoc
        @material_assoc.relatedobjects.add(ifc_entity)
      end

      # Add the stylings to a shaperepresentation
      #
      # @param ifc_entity [IfcShapeRepresentation] IFC Entity
      def add_to_styling(ifc_entity)
        @surface_styles ||= create_surface_styles
        if @surface_styles
          styled_item = @ifc::IfcStyledItem.new(@ifc_model, ifc_entity)
          styled_item.styles = @surface_styles
        end
      end
    end
  end
end
