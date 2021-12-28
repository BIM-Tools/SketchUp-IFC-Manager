#  IfcCartesianPoint_su.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'IfcReal.rb'

module BimTools
  module IfcCartesianPoint_su
    include IfcManager
    def initialize(ifc_model, sketchup)
      super
      case sketchup
      when Geom::Point3d
        x_step = IfcReal.new(sketchup.x.to_f.to_mm).step
        y_step = IfcReal.new(sketchup.y.to_f.to_mm).step
        z_step = IfcReal.new(sketchup.z.to_f.to_mm).step
        @coordinates = Ifc_List.new([x_step,y_step,z_step])        
      when Geom::Point2d
        x_step = IfcReal.new(sketchup.x.to_f.to_mm).step
        y_step = IfcReal.new(sketchup.y.to_f.to_mm).step
        @coordinates = Ifc_List.new([x_step,y_step])        
      else
        raise TypeError, "Expected a point type."
      end
    end # def sketchup
  end # module IfcCartesianPoint_su
end # module BimTools
