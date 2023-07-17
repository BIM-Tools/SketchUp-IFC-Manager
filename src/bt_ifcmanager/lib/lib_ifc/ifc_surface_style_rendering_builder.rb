# frozen_string_literal: true

#  ifc_surface_style_rendering_builder.rb
#
#  Copyright 2023 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcManager
    class IfcSurfaceStyleRenderingBuilder
      attr_reader :ifc_surface_style_rendering

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_surface_style_rendering
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model

        # IFC2x3 IfcSurfaceStyleRendering
        # @todo IFC4 IfcSurfaceStyleShading (transparency change)
        if @ifc::IfcSurfaceStyleShading.respond_to?(:transparency)
          @ifc_surface_style_rendering = @ifc::IfcSurfaceStyleShading.new(ifc_model)
        else
          @ifc_surface_style_rendering = @ifc::IfcSurfaceStyleRendering.new(ifc_model)
          @ifc_surface_style_rendering.reflectancemethod = :notdefined
        end
      end

      # Set the color for the IfcSurfaceStyleRendering
      #
      # @param [Sketchup::Color] color
      def set_surface_colour(color)
        red_ratio = color.red.to_f / 255
        green_ratio = color.green.to_f / 255
        blue_ratio = color.blue.to_f / 255

        colourrgb = @ifc::IfcColourRgb.new(@ifc_model)
        colourrgb.red = Types::IfcNormalisedRatioMeasure.new(@ifc_model, red_ratio)
        colourrgb.green = Types::IfcNormalisedRatioMeasure.new(@ifc_model, green_ratio)
        colourrgb.blue = Types::IfcNormalisedRatioMeasure.new(@ifc_model, blue_ratio)
        @ifc_surface_style_rendering.surfacecolour = colourrgb
      end

      # Set the transparency value for the IfcSurfaceStyleRendering
      #
      # @param [Float] alpha
      def set_transparency(alpha)
        alpha_ratio = 1 - alpha
        @ifc_surface_style_rendering.transparency = Types::IfcNormalisedRatioMeasure.new(@ifc_model,
                                                                                         alpha_ratio)
      end
    end
  end
end
