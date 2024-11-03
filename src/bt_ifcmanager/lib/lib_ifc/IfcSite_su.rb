# frozen_string_literal: true

#  IfcSite_su.rb
#
#  Copyright 2019 Jan Brouwer <jan@brewsky.nl>
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
  module IfcSite_su
    # def reflatitude=(values)
    #   if valid_latlong_list?(values)
    #     @reflatitude = values
    #   else
    #     puts 'Invalid reflatitude values'
    #   end
    # end

    # def reflongitude=(values)
    #   if valid_latlong_list?(values)
    #     @reflongitude = values
    #   else
    #     puts 'Invalid reflongitude values'
    #   end
    # end

    # Sets the reference latitude, longitude, and elevation for the given IfcSite entity
    # based on the corresponding values from the SketchUp model.
    #
    # @param ifc_site [IfcSite] The IfcSite entity to set the attributes for.
    # @return [void]
    def set_geo_location_from_model
      geo_reference = @ifc_model.su_model.attribute_dictionary('GeoReference')
      # shadow_info = @ifc_model.su_model.shadow_info
      # latitude = shadow_info['Latitude']
      # longitude = shadow_info['Longitude']
      # elevation = shadow_info['Elevation']
      latitude = geo_reference['Latitude']
      longitude = geo_reference['Longitude']
      elevation = geo_reference['ModelTranslationZ'] ? geo_reference['ModelTranslationZ'] * -1 : 0

      self.reflatitude = convert_to_compound_plane_angle_measure(latitude) if latitude
      self.reflongitude = convert_to_compound_plane_angle_measure(longitude) if longitude
      self.refelevation = IfcManager::Types::IfcLengthMeasure.new(@ifc_model, elevation) if elevation
    end

    private

    def valid_latlong_list?(values)
      values.is_a?(Array) && values.all? { |v| v.is_a?(IfcCompoundPlaneAngleMeasure) }
    end

    # Converts a decimal degree value to a compound plane angle measure.
    #
    # @param decimal_degrees [Float] The decimal degree value to be converted.
    # @return [Types::IfcCompoundPlaneAngleMeasure] The converted compound plane angle measure.
    def convert_to_compound_plane_angle_measure(decimal_degrees)
      degrees = decimal_degrees.to_i
      minutes = ((decimal_degrees - degrees) * 60).to_i
      seconds = (((decimal_degrees - degrees) * 60 - minutes) * 60).to_i
      millionths = ((((decimal_degrees - degrees) * 60 - minutes) * 60 - seconds) * 1_000_000).to_i

      IfcManager::Types::IfcCompoundPlaneAngleMeasure.new(@ifc_model, [degrees, minutes, seconds, millionths])
    end
  end
end
