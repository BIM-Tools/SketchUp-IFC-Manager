#  IfcDirection_su.rb
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
  module IfcDirection_su
    def initialize(ifc_model, sketchup)
      super
      case sketchup
      when Geom::Vector3d, Geom::Vector2d        
        
        # round values
        @directionratios = IfcManager::Ifc_List.new(sketchup.to_a.map{|x| IfcManager::IfcReal.new(x)})
      else
        raise TypeError, "Expected a vector type."
      end
    end
  end
end
