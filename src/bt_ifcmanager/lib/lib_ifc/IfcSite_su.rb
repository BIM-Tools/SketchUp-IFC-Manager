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

    # add project location, if set in sketchup model
    # (!) north angle still missing?
    def set_latlong
      if Sketchup.active_model.georeferenced?
        local_point = Geom::Point3d.new( [0,0,0] )
        @latlong = Sketchup.active_model.point_to_latlong( local_point )
      end
    end
    def latitude
      if @latlong
        return lat_long_ifc(@latlong[1])
      end
    end
    def longtitude
      if @latlong
        return lat_long_ifc(@latlong[0])
      end
    end
    def elevation
      if @latlong
        return BimTools::IfcManager::IfcLengthMeasure.new( @latlong[2] )
      end
    end
    
    # convert sketchup latlong coordinate (decimal) to IFC notation (degrees)
    def lat_long_ifc( coordinate )
      if Sketchup.active_model.georeferenced?
        d = coordinate.abs()
        neg_pos = (coordinate / d).to_int

        # degrees
        i = d.to_int
        deg = i * neg_pos

        # minutes
        d = d - i
        d = d * 60
        i = d.to_int

        min = i * neg_pos

        # seconds
        d = d - i
        d = d * 60
        i = d.to_int
        sec = i * neg_pos

        # millionth-seconds
        d = d - i
        d = d * 1000000
        i = d.to_int
        msec = i * neg_pos

         # (!) values should be Ifc INTEGER objects instead of Strings(!)
         # (!) returned object should be of type IFC LIST instead of IFC SET
        return BimTools::IfcManager::Ifc_Set.new([deg.to_s, min.to_s, sec.to_s, msec.to_s])
      end
    end
  end # module IfcSite_su
end # module BimTools
