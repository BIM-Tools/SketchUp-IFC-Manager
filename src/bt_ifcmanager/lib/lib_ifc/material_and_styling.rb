# frozen_string_literal: true

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

require_relative 'ifc_types'
require_relative 'ifc_surface_style_rendering_builder'

module BimTools
  module IfcManager
    # This class manages the relationship between a SketchUp material and its corresponding IFC material and styles.
    # It provides a bridge between the SketchUp material and the IFC schema, allowing for the conversion of SketchUp materials into IFC materials and styles.
    #
    # @param [IfcModel] ifc_model The IFC model that the SketchUp material will be converted into.
    # @param [Sketchup::Material] su_material The SketchUp material that will be converted into an IFC material and styles.
    class MaterialAndStyling
      attr_reader :image_texture

      def initialize(ifc_model, su_material = nil)
        @ifc_model = ifc_model
        @ifc = Settings.ifc_module
        @su_material = su_material
        @image_texture = create_image_texture(su_material)
        @surface_style_rendering = create_surface_style_rendering(su_material)
        @surface_styles_both = nil
        @surface_styles_positive = nil
        @surface_styles_negative = nil
      end

      # This method creates an IfcRelAssociatesMaterial object, which represents a relationship between a material definition and the elements or element types that this material applies to in the IFC schema.
      #
      # @param [Sketchup::Material, nil] su_material The SketchUp material to be associated. If no material is provided, a default material is created.
      #
      # @return [IfcRelAssociatesMaterial] The created IfcRelAssociatesMaterial object, which associates the provided material (or a default material) with certain elements or element types.
      def create_material_assoc(su_material = nil)
        material_name = if su_material
                          su_material.display_name
                        else
                          'Default'
                        end
        persistent_id = if su_material
                          su_material.persistent_id
                        else
                          'IfcMaterial.Default'
                        end

        material_assoc = @ifc::IfcRelAssociatesMaterial.new(@ifc_model)
        material_assoc.globalid = IfcManager::IfcGloballyUniqueId.new(@ifc_model, persistent_id)
        material_assoc.relatingmaterial = @ifc::IfcMaterial.new(@ifc_model)
        material_assoc.relatingmaterial.name = Types::IfcLabel.new(@ifc_model, material_name)
        material_assoc.relatedobjects = Types::Set.new
        material_assoc
      end

      # This method is responsible for creating IFC surface styles.
      # An IFC surface style provides a mechanism for attaching visual style properties to geometric representations.
      #
      # @param [Sketchup::Material] su_material The SketchUp material to be converted into an IFC surface style.
      # @param [Symbol] side The side of the surface that the style applies to. Can be :both, :positive, or :negative.
      #
      # @return [Ifc_Set] A set of IFC surface styles. This includes the main surface style and, if an image texture is present, a texture style.
      def create_surface_styles(su_material, side = :both)
        if su_material
          name = su_material.display_name
          surface_style_rendering = @surface_style_rendering
        else
          name = 'Default'
          surface_style_rendering = get_default_surface_style_rendering(side)
        end

        surface_style = @ifc::IfcSurfaceStyle.new(@ifc_model)
        surface_style.side = side
        surface_style.name = Types::IfcLabel.new(@ifc_model, name)
        surface_style.styles = Types::Set.new([surface_style_rendering])

        if @image_texture
          texture_style = @ifc::IfcSurfaceStyleWithTextures.new(@ifc_model)
          texture_style.textures = IfcManager::Types::List.new([@image_texture])
          surface_style.styles.add(texture_style)
        end

        # Workaround for mandatory IfcPresentationStyleAssignment in IFC2x3
        if Settings.ifc_version == 'IFC 2x3'
          style_assignment = @ifc::IfcPresentationStyleAssignment.new(@ifc_model)
          style_assignment.styles = Types::Set.new([surface_style])
        else
          style_assignment = surface_style
        end

        style_assignment
      end

      # Creates an IFC surface style rendering object based on the given SketchUp material.
      # The IFC surface style rendering object represents the visual appearance of a surface in the IFC model.
      #
      # @param su_material [Sketchup::Material] The SketchUp material used to create the IFC surface style rendering.
      # @return [void]
      def create_surface_style_rendering(su_material)
        return unless su_material

        IfcSurfaceStyleRenderingBuilder.build(@ifc_model) do |builder|
          builder.set_surface_colour(su_material.color)
          builder.set_transparency(su_material.alpha)
        end
      end

      # Returns the default surface style rendering for the given side.
      # If the side is :negative, it returns the rendering for the back face color.
      # If the side is :positive or :both, it returns the rendering for the front face color.
      #
      # @param side [Symbol] The side for which to get the rendering.
      # @return [IfcSurfaceStyleRendering] The default surface style rendering.
      def get_default_surface_style_rendering(side = :both)
        return @@default_rendering if defined?(@@default_rendering)

        rendering_options = @ifc_model.su_model.rendering_options
        color = if side == :negative
                  rendering_options['FaceBackColor']
                else
                  rendering_options['FaceFrontColor']
                end

        @@default_rendering = IfcSurfaceStyleRenderingBuilder.build(@ifc_model) do |builder|
          builder.set_surface_colour(color)
          builder.set_transparency(1.0)
        end

        @@default_rendering
      end

      # Creates an image texture for the given SketchUp material.
      #
      # @param su_material [Sketchup::Material] The SketchUp material.
      # @return [IfcEngine::IfcImageTexture, nil] The created IfcImageTexture object, or nil if the texture cannot be created.
      def create_image_texture(su_material)
        # export textures for IFC 4 and up only, check if IfcTextureMap is available
        return unless @ifc_model.textures
        return unless @ifc::IfcTextureMap.method_defined?(:maps)
        return unless su_material

        su_texture = su_material.texture
        return unless su_texture

        image_texture = @ifc::IfcImageTexture.new(@ifc_model)
        image_texture.repeats = true
        image_texture.repeatt = true
        texturetransform = @ifc::IfcCartesianTransformationOperator2DnonUniform.new(@ifc_model)
        texturetransform.axis1 = @ifc::IfcDirection.new(@ifc_model, Geom::Vector2d.new(0, 1))
        texturetransform.axis2 = @ifc::IfcDirection.new(@ifc_model, Geom::Vector2d.new(1, 0))
        texturetransform.localorigin = @ifc::IfcCartesianPoint.new(@ifc_model, Geom::Point2d.new(0, 0))
        texturetransform.scale = Types::IfcReal.new(@ifc_model,
                                                    Types::IfcLengthMeasure.new(@ifc_model,
                                                                                su_texture.width).convert)
        texturetransform.scale2 = Types::IfcReal.new(@ifc_model,
                                                     Types::IfcLengthMeasure.new(@ifc_model,
                                                                                 su_texture.height).convert)
        image_texture.texturetransform = texturetransform
        image_texture.urlreference = Types::IfcURIReference.new(@ifc_model,
                                                                File.basename(su_texture.filename))
        image_texture
      end

      # Add the material to an IFC entity
      #
      # @param[IfcProduct] ifc_entity IFC Entity
      def add_to_material(ifc_entity)
        @material_assoc ||= create_material_assoc(@su_material)
        @material_assoc.relatedobjects.add(ifc_entity)
      end

      # Add the stylings to a shaperepresentation
      #
      # @param [IfcRepresentationItem] representation_item
      def get_styling(side = nil)
        return unless @ifc_model.options[:colors]

        case side
        when :positive
          @surface_styles_positive ||= create_surface_styles(@su_material, side)
        when :negative
          @surface_styles_negative ||= create_surface_styles(@su_material, side)
        else # :both
          @surface_styles_both ||= create_surface_styles(@su_material, :both)
        end
      end
    end
  end
end
