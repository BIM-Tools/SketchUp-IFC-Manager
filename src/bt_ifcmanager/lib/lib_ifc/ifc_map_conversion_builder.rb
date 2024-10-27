# frozen_string_literal: true

#  ifc_map_conversion_builder.rb
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

module BimTools
  module IfcManager
    class IfcMapConversionBuilder
      attr_reader :ifc_map_conversion

      def self.build(ifc_model)
        builder = new(ifc_model)
        return nil unless builder.ifc_map_conversion

        yield(builder)
        builder.ifc_map_conversion
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        return unless @ifc.const_defined?(:IfcMapConversion)

        @ifc_model = ifc_model
        @ifc_map_conversion = @ifc::IfcMapConversion.new(ifc_model)
      end

      def set_source_crs(source_crs)
        @ifc_map_conversion.sourcecrs = source_crs if source_crs
      end

      def set_target_crs(target_crs)
        @ifc_map_conversion.targetcrs = target_crs if target_crs
      end

      def set_eastings(eastings)
        return unless eastings

        @ifc_map_conversion.eastings = IfcManager::Types::IfcReal.new(@ifc_model, eastings)
      end

      def set_northings(northings)
        return unless northings

        @ifc_map_conversion.northings = IfcManager::Types::IfcReal.new(@ifc_model, northings)
      end

      def set_orthogonalheight(orthogonalheight)
        return unless orthogonalheight

        @ifc_map_conversion.orthogonalheight = IfcManager::Types::IfcReal.new(@ifc_model, orthogonalheight)
      end

      def set_xaxisabscissa(xaxisabscissa)
        return unless xaxisabscissa

        @ifc_map_conversion.xaxisabscissa = IfcManager::Types::IfcReal.new(@ifc_model, xaxisabscissa)
      end

      def set_xaxisordinate(xaxisordinate)
        return unless xaxisordinate

        @ifc_map_conversion.xaxisordinate = IfcManager::Types::IfcReal.new(@ifc_model, xaxisordinate)
      end

      def set_scale(scale)
        return unless scale

        @ifc_map_conversion.scale = IfcManager::Types::IfcReal.new(@ifc_model, scale)
      end

      # Calculates the scale factor for the given IFC model with 1 meter as the base value
      #
      # @param ifc_model [Object] The IFC model to calculate the scale factor for.
      # @return [Numeric] The scale factor calculated for the given `ifc_model`.
      def calculate_scale(ifc_model)
        length_measure = IfcManager::Types::IfcLengthMeasure.new(ifc_model, 1.0.m)

        length_measure.convert
      end

      def set_from_utm(representationcontext, projected_crs, utm_point)
        # Determine the hemisphere based on the zone letter
        hemisphere = utm_point.zone_letter >= 'N' ? 'N' : 'S'
        y = utm_point.y
        x = utm_point.x
        equator_height = 10_000_000

        # Adjust the y value if the hemisphere is south
        utm_point.y = 2 * equator_height - utm_point.y if hemisphere == 'S'

        set_source_crs(representationcontext)
        set_target_crs(projected_crs)
        set_eastings(x)
        set_northings(y)
        set_orthogonalheight(0.0)
        set_xaxisabscissa(1.0)
        set_xaxisordinate(0.0)
        set_scale(calculate_scale(@ifc_model))
      end
    end
  end
end
