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
    def initialize(ifc_model, su_instance, su_total_transformation)
      @ifc_model = ifc_model
      @su_model = ifc_model.su_model
      super
    end

    def reflatitude=(_values)
      puts "Function 'reflatitude=' for 'IfcSite' not implemented"
    end

    def reflongitude=(_values)
      puts "Function 'reflongitude=' for 'IfcSite' not implemented"
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
