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

module BimTools
  module IfcSite_su
    @reflatitude = nil
    @reflongitude = nil

    # add project location, if set in sketchup model
    # (!) north angle still missing?
    def set_latlong
      return unless Sketchup.active_model.georeferenced?

      local_point = Geom::Point3d.new([0, 0, 0])
      @latlong = Sketchup.active_model.point_to_latlong(local_point)
    end

    def reflatitude=(values)
      if valid_latlong_list?(values)
        @reflatitude = values
      else
        puts 'Invalid reflatitude values'
      end
    end

    def reflongitude=(values)
      if valid_latlong_list?(values)
        @reflongitude = values
      else
        puts 'Invalid reflongitude values'
      end
    end

    def reflatitude
      lat_long_ifc(@latlong[1]) if @latlong
    end

    def reflongitude
      lat_long_ifc(@latlong[0]) if @latlong
    end

    def elevation
      IfcManager::Types::IfcLengthMeasure.new(@ifc_model, @latlong[2]) if @latlong
    end

    private

    def valid_latlong_list?(values)
      values.is_a?(Array) && values.all? { |v| v.is_a?(IfcCompoundPlaneAngleMeasure) }
    end

    # convert sketchup latlong coordinate (decimal) to IFC notation (degrees)
    def lat_long_ifc(coordinate)
      return unless Sketchup.active_model.georeferenced?

      d = coordinate.abs
      neg_pos = (coordinate / d).to_int

      # degrees
      i = d.to_int
      deg = i * neg_pos

      # minutes
      d -= i
      d *= 60
      i = d.to_int

      min = i * neg_pos

      # seconds
      d -= i
      d *= 60
      i = d.to_int
      sec = i * neg_pos

      # millionth-seconds
      d -= i
      d *= 1_000_000
      i = d.to_int
      msec = i * neg_pos

      # (!) values should be Ifc INTEGER objects instead of Strings(!)
      # (!) returned object should be of type IFC LIST instead of IFC SET
      IfcManager::Types::List.new([deg.to_s, min.to_s, sec.to_s, msec.to_s])
    end
  end
end
