# frozen_string_literal: true

#  geolocation_builder.rb
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
require_relative 'ifc_map_conversion_builder'
require_relative 'ifc_projected_crs_builder'

module BimTools
  module IfcManager
    class GeolocationBuilder
      attr_reader :ifc_quantity

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.validate
        builder.ifc_quantity
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_version = Settings.ifc_version
        @latitude = nil
        @longitude = nil
        @north_vector = nil
        @origin_point = nil
      end

      def validate
        @north_vector ||= Geom::Vector3d.new([0, 1, 0])
        @origin_point ||= Geom::Point3d.new([0, 0, 0])
      end

      def set_origin(point)
        @origin_point = point
      end

      def set_north_vector(vector)
        @north_vector = vector
      end

      def set_latitude(latitude)
        @latitude = latitude
      end

      def set_longitude(longitude)
        @longitude = longitude
      end

      def setup_geolocation(world_transformation)
        return if @ifc_version == 'IFC 2x3'

        su_model = @ifc_model.su_model
        return unless su_model.georeferenced?

        @geo_reference = su_model.attribute_dictionary('GeoReference')
        return unless @geo_reference

        # LatLong point includes the Z value
        latlong_point = su_model.point_to_latlong(world_transformation.origin)
        utm_point = su_model.point_to_utm(world_transformation.origin)

        projected_crs = IfcManager::IfcProjectedCRSBuilder.build(@ifc_model) do |builder|
          builder.set_from_utm(utm_point)
        end

        IfcManager::IfcMapConversionBuilder.build(@ifc_model) do |builder|
          builder.set_from_utm(@ifc_model.representationcontext, projected_crs, utm_point, world_transformation)
          builder.set_orthogonalheight(latlong_point.z)
        end
        # add_additional_ifc_entities(@ifc_model.representationcontext, utm_point)
      end

      private

      # Calculates the EPSG code based on the UTM point.
      #
      # @param utm_point [UTMPoint] The UTM point containing the zone number and zone letter.
      # @return [String] The EPSG code in the format "EPSG:#{epsg_code}".
      def get_epsg_code(utm_point)
        zone_number = utm_point.zone_number
        zone_letter = utm_point.zone_letter

        # Determine the hemisphere based on the zone letter
        hemisphere = zone_letter >= 'N' ? 'N' : 'S'

        zone_code = hemisphere == 'N' ? 32_600 : 32_700
        epsg_code = zone_code + zone_number.to_i

        ["EPSG:#{epsg_code}", "WGS 84 / UTM zone #{zone_number}#{zone_letter}"]
      end

      # Calculates the scale factor for the given IFC model with 1 meter as the base value
      #
      # @param ifc_model [Object] The IFC model to calculate the scale factor for.
      # @return [Numeric] The scale factor calculated for the given `ifc_model`.
      def calculate_scale(ifc_model)
        length_measure = IfcManager::Types::IfcLengthMeasure.new(ifc_model, 1.0)

        length_measure.convert
      end

      # # Adds additional IFC entities to the representation context with the specified UTM point.
      # #
      # # @param [RepresentationContext] representationcontext The representation context to add the entities to.
      # # @param [UTMPoint] utm_point The UTM point used for the map conversion.
      # # @return [void]
      # def add_additional_ifc_entities(representationcontext, utm_point)
      #   return unless @ifc.const_defined?(:IfcProjectedCRS)

      #   epsg_code, epsg_description = get_epsg_code(utm_point)

      #   projected_crs = @ifc::IfcProjectedCRS.new(@ifc_model)
      #   projected_crs.name = IfcManager::Types::IfcLabel.new(@ifc_model, epsg_code)
      #   projected_crs.description = IfcManager::Types::IfcText.new(@ifc_model, epsg_description)
      #   projected_crs.geodeticdatum = IfcManager::Types::IfcIdentifier.new(@ifc_model, 'WGS 84')

      #   mapunit = @ifc::IfcSIUnit.new(@ifc_model)
      #   mapunit.unittype = :LENGTHUNIT
      #   mapunit.prefix = nil
      #   mapunit.name = :METRE
      #   projected_crs.mapunit = mapunit

      #   mapconversion = @ifc::IfcMapConversion.new(@ifc_model)
      #   mapconversion.sourcecrs = representationcontext
      #   mapconversion.targetcrs = projected_crs
      #   mapconversion.eastings = IfcManager::Types::IfcReal.new(@ifc_model, utm_point.x)
      #   mapconversion.northings = IfcManager::Types::IfcReal.new(@ifc_model, utm_point.y)
      #   mapconversion.orthogonalheight = IfcManager::Types::IfcReal.new(@ifc_model, 0.0)
      #   mapconversion.xaxisabscissa = IfcManager::Types::IfcReal.new(@ifc_model, 1.0)
      #   mapconversion.xaxisordinate = IfcManager::Types::IfcReal.new(@ifc_model, 0.0)
      #   mapconversion.scale = IfcManager::Types::IfcReal.new(@ifc_model, calculate_scale(@ifc_model))

      #   IfcManager::IfcProjectedCRSBuilder.build(@ifc_model) do |builder|
      #     builder.set_from_utm(utm_point)
      #   end

      #   IfcManager::IfcMapConversionBuilder.build(@ifc_model) do |builder|
      #     builder.set_from_utm(representationcontext, utm_point)
      #   end
      # end
    end
  end
end
