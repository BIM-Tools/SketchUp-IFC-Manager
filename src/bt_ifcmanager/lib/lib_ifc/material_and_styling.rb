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
    # Manages the relationship between a SketchUp material and its corresponding IFC material and styles.
    class MaterialAndStyling
      attr_reader :image_texture

      # Initializes the MaterialAndStyling object.
      #
      # @param [IfcModel] ifc_model The IFC model that the SketchUp material will be converted into.
      # @param [Sketchup::Material] su_material The SketchUp material that will be converted into an IFC material and styles.
      def initialize(ifc_model, su_material = nil)
        @ifc_model = ifc_model
        @ifc_module = ifc_model.ifc_module
        @su_material = su_material
        @image_texture = nil
        @surface_style_rendering = nil
        @surface_styles = {}
        @styling_initialized = false
      end

      # Add the material to an IFC entity.
      #
      # @param [IfcProduct] ifc_entity IFC Entity
      def add_to_material(ifc_entity)
        @material_assoc ||= create_material_assoc(@su_material)
        @material_assoc.relatedobjects.add(ifc_entity)
      end

      # Add the stylings to a shape representation.
      #
      # @param [Symbol, nil] side The side of the surface that the style applies to. Can be :both, :positive, or :negative.
      # @return [Ifc_Set, nil] A set of IFC surface styles, or nil if colors are not enabled in the IFC model options.
      def get_styling(side = nil)
        return unless @ifc_model.options[:colors]

        initialize_styling(side) unless @styling_initialized

        @surface_styles[side]
      end

      private

      def initialize_styling(side)
        @surface_styles[side] = create_surface_styles(@su_material, side || :both)
        if @ifc_model.textures && @su_material && @su_material.texture
          @image_texture = create_image_texture(@su_material)
        end
        @styling_initialized = true
      end

      def create_material_assoc(su_material = nil)
        material_name, persistent_id = material_details(su_material)
        material_assoc = @ifc_module::IfcRelAssociatesMaterial.new(@ifc_model)
        material_assoc.globalid = IfcManager::IfcGloballyUniqueId.new(@ifc_model, persistent_id)
        material_assoc.relatingmaterial = create_ifc_material(su_material, material_name)
        material_assoc.relatedobjects = Types::Set.new
        material_assoc
      end

      def create_surface_style_rendering(su_material)
        return unless su_material

        IfcSurfaceStyleRenderingBuilder.build(@ifc_model) do |builder|
          builder.set_surface_colour(su_material.color)
          builder.set_transparency(su_material.alpha)
        end
      end

      def create_surface_styles(su_material, side = :both)
        surface_style_rendering = su_material ? create_surface_style_rendering(su_material) : get_default_surface_style_rendering(side)
        surface_style = build_surface_style(su_material, side, surface_style_rendering)
        add_texture_style(surface_style) if @image_texture
        assign_style(surface_style)
      end

      def get_default_surface_style_rendering(side = :both)
        return @default_rendering if defined?(@default_rendering)

        color = default_color(side)
        @default_rendering = IfcSurfaceStyleRenderingBuilder.build(@ifc_model) do |builder|
          builder.set_surface_colour(color)
          builder.set_transparency(1.0)
        end
        @default_rendering
      end

      def create_image_texture(su_material)
        return unless @ifc_model.textures && su_material && su_material.texture

        su_texture = su_material.texture
        image_texture = @ifc_module::IfcImageTexture.new(@ifc_model)
        image_texture.repeats = true
        image_texture.repeatt = true
        image_texture.texturetransform = create_texture_transform(su_texture)
        image_texture.urlreference = Types::IfcURIReference.new(@ifc_model, File.basename(su_texture.filename))
        image_texture
      end

      def material_details(su_material)
        if su_material
          [su_material.display_name, su_material.persistent_id]
        else
          ['Default', 'IfcMaterial.Default']
        end
      end

      def create_ifc_material(su_material, material_name)
        material = @ifc_module::IfcMaterial.new(@ifc_model, su_material)
        material.name = Types::IfcLabel.new(@ifc_model, material_name)
        material
      end

      def build_surface_style(su_material, side, surface_style_rendering)
        name = su_material ? su_material.display_name : 'Default'
        surface_style = @ifc_module::IfcSurfaceStyle.new(@ifc_model)
        surface_style.side = side
        surface_style.name = Types::IfcLabel.new(@ifc_model, name)
        surface_style.styles = Types::Set.new([surface_style_rendering])
        surface_style
      end

      def add_texture_style(surface_style)
        texture_style = @ifc_module::IfcSurfaceStyleWithTextures.new(@ifc_model)
        texture_style.textures = IfcManager::Types::List.new([@image_texture])
        surface_style.styles.add(texture_style)
      end

      def assign_style(surface_style)
        if @ifc_model.ifc_version == 'IFC 2x3'
          style_assignment = @ifc_module::IfcPresentationStyleAssignment.new(@ifc_model)
          style_assignment.styles = Types::Set.new([surface_style])
        else
          style_assignment = surface_style
        end
        style_assignment
      end

      def default_color(side)
        rendering_options = @ifc_model.su_model.rendering_options
        side == :negative ? rendering_options['FaceBackColor'] : rendering_options['FaceFrontColor']
      end

      def create_texture_transform(su_texture)
        texturetransform = @ifc_module::IfcCartesianTransformationOperator2DnonUniform.new(@ifc_model)
        texturetransform.axis1 = @ifc_module::IfcDirection.new(@ifc_model, Geom::Vector2d.new(0, 1))
        texturetransform.axis2 = @ifc_module::IfcDirection.new(@ifc_model, Geom::Vector2d.new(1, 0))
        texturetransform.localorigin = @ifc_module::IfcCartesianPoint.new(@ifc_model, Geom::Point2d.new(0, 0))
        texturetransform.scale = Types::IfcReal.new(@ifc_model,
                                                    Types::IfcLengthMeasure.new(@ifc_model, su_texture.width).convert)
        texturetransform.scale2 = Types::IfcReal.new(@ifc_model,
                                                     Types::IfcLengthMeasure.new(@ifc_model, su_texture.height).convert)
        texturetransform
      end
    end
  end
end
