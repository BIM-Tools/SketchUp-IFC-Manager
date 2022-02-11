#  IfcAxis2Placement3D_su.rb
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

require_relative 'IfcReal'

module BimTools
  module IfcAxis2Placement3D_su
    def initialize(ifc_model, transformation = nil)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module
      if transformation.is_a? Geom::Transformation
        @location = @ifc::IfcCartesianPoint.new(ifc_model, transformation.origin)
        @axis = @ifc::IfcDirection.new(ifc_model, transformation.zaxis)
        @refdirection = @ifc::IfcDirection.new(ifc_model, transformation.xaxis)
      end
    end
  end
end
