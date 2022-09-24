# frozen_string_literal: true

#  IfcLocalPlacement_su.rb
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

module BimTools
  module IfcLocalPlacement_su


    attr_accessor :transformation, :ifc_total_transformation

    def initialize(ifc_model, su_total_transformation = nil, placementrelto = nil)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module

      # set parent placement
      @placementrelto = placementrelto # if placementrelto.is_a?(IfcLocalPlacement)

      if su_total_transformation.is_a?(Geom::Transformation)

        # fix y-axis direction if flipped
        t = su_total_transformation
        axis_fix = if t.xaxis.cross(t.yaxis).samedirection?(t.zaxis)
                     Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1])
                   else
                     Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, -1, 0], [0, 0, 1])
                   end

        # strip out scaling
        t = su_total_transformation.to_a
        x = t[0..2].normalize # is the xaxis
        y = t[4..6].normalize # is the yaxis
        z = t[8..10].normalize # is the zaxis
        no_scale = Geom::Transformation.axes(su_total_transformation.origin, x, y, z)

        @ifc_total_transformation = no_scale * axis_fix

        @transformation = if !@placementrelto.nil? && @placementrelto.ifc_total_transformation
                            @placementrelto.ifc_total_transformation.inverse * @ifc_total_transformation
                          else
                            @ifc_total_transformation
                          end

        # set relativeplacement
        @relativeplacement = @ifc::IfcAxis2Placement3D.new(ifc_model, @transformation)
      end
    end
  end
end
