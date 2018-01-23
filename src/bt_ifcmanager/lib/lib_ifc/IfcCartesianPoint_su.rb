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
    def initialize(ifc_model, sketchup)
      super
      if sketchup.is_a? Geom::Point3d
        
        # set coordinates
        x = sketchup.x.to_f*25.4
        y = sketchup.y.to_f*25.4
        z = sketchup.z.to_f*25.4
        
        @coordinates = "(#{IfcManager::IfcReal.new(x).step}, #{IfcManager::IfcReal.new(y).step}, #{IfcManager::IfcReal.new(z).step})"
      end
      
    end # def sketchup
  end # module IfcCartesianPoint_su
end # module BimTools
