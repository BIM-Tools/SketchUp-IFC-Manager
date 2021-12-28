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
    include BimTools::IfcManager::Settings.ifc_module

    attr_accessor :transformation, :ifc_total_transformation
    def initialize(ifc_model, su_total_transformation, placementrelto=nil )
      super
      @ifc_model = ifc_model
      
      # set parent placement
      if placementrelto.is_a? IfcLocalPlacement
        @placementrelto = placementrelto
      end
      
      # fix y-axis direction if flipped
      t = su_total_transformation
      if t.xaxis.cross(t.yaxis).samedirection?( t.zaxis )
        axis_fix = Geom::Transformation.axes( [0,0,0], [1,0,0], [0,1,0], [0,0,1] )
      else
        axis_fix = Geom::Transformation.axes( [0,0,0], [1,0,0], [0,-1,0], [0,0,1] )
      end
      
      # strip out scaling
      t = su_total_transformation.to_a
      #sx = Geom::Vector3d.new([t[0],t[4],t[8]])
      #sy = Geom::Vector3d.new([t[1],t[5],t[9]])
      #sz = Geom::Vector3d.new([t[2],t[6],t[10]])
      #scale = Geom::Transformation.scaling(sx.length, sy.length, sz.length)
      x = t[0..2].normalize # is the xaxis
      y = t[4..6].normalize # is the yaxis
      z = t[8..10].normalize # is the zaxis
      no_scale = Geom::Transformation.axes(su_total_transformation.origin, x, y, z)
      
      @ifc_total_transformation = no_scale * axis_fix
      
      if @placementrelto
        @transformation = @placementrelto.ifc_total_transformation.inverse * @ifc_total_transformation
      else
        @transformation = @ifc_total_transformation
      end
      
      # set relativeplacement
      @relativeplacement = IfcAxis2Placement3D.new( @ifc_model, @transformation )
      @relativeplacement.location = IfcCartesianPoint.new( @ifc_model, @transformation.origin )
      @relativeplacement.axis = IfcDirection.new( @ifc_model, @transformation.zaxis )
      @relativeplacement.refdirection = IfcDirection.new( @ifc_model, @transformation.xaxis )
    end
  end # module IfcLocalPlacement_su
end # module BimTools
