# frozen_string_literal: true

#  ifc_projected_crs_builder.rb
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
    class IfcProjectedCRSBuilder
      attr_reader :ifc_projected_crs

      def self.build(ifc_model)
        builder = new(ifc_model)
        return nil unless builder.ifc_projected_crs

        yield(builder)
        builder.ifc_projected_crs
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        return unless @ifc.const_defined?(:IfcProjectedCRS)

        @ifc_model = ifc_model
        @ifc_projected_crs = @ifc::IfcProjectedCRS.new(ifc_model)
      end

      def set_name(name)
        @ifc_projected_crs.name = Types::IfcLabel.new(@ifc_model, name) if name
      end

      def set_description(description)
        @ifc_projected_crs.description = Types::IfcText.new(@ifc_model, description) if description
      end

      def set_geodeticdatum(geodeticdatum)
        return unless geodeticdatum

        @ifc_projected_crs.geodeticdatum = Types::IfcIdentifier.new(@ifc_model, geodeticdatum)
      end

      def set_mapunit(map_unit)
        @ifc_projected_crs.mapunit = map_unit
      end

      # Calculates the EPSG code based on the UTM point.
      #
      # @param utm_point [UTMPoint] The UTM point containing the zone number and zone letter.
      # @return [String] The EPSG code in the format "EPSG:#{epsg_code}".
      def get_epsg(utm_point)
        zone_number = utm_point.zone_number
        zone_letter = utm_point.zone_letter

        # Determine the hemisphere based on the zone letter
        hemisphere = zone_letter >= 'N' ? 'N' : 'S'

        zone_code = hemisphere == 'N' ? 32_600 : 32_700
        epsg_code = zone_code + zone_number.to_i
        epsg_name = "EPSG:#{epsg_code}"
        epsg_description = "#{epsg_name} - WGS 84 / UTM zone #{zone_number}#{hemisphere}"
        # epsg_description = "WGS 84 / UTM zone #{zone_number}#{zone_letter}"

        [epsg_name, epsg_description]
      end

      def set_from_utm(utm_point)
        epsg_name, epsg_description = get_epsg(utm_point)
        set_name(epsg_name)
        set_description(epsg_description)
        set_geodeticdatum('WGS 84')
        set_mapunit(@ifc_model.units.length_unit_entity)
      end
    end
  end
end
