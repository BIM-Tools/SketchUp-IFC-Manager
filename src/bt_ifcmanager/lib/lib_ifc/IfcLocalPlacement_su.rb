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

require_relative File.join('IFC2X3', 'IfcAxis2Placement3D.rb')

module BimTools
  module IfcLocalPlacement_su
    attr_accessor :transformation, :ifc_total_transformation
    
    include IFC2X3
    
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
      sx = Geom::Vector3d.new([t[0],t[4],t[8]])
      sy = Geom::Vector3d.new([t[1],t[5],t[9]])
      sz = Geom::Vector3d.new([t[2],t[6],t[10]])
      scale = Geom::Transformation.scaling(sx.length, sy.length, sz.length)
      
      @ifc_total_transformation = scale.inverse * su_total_transformation * axis_fix
      
      if self.placementrelto
        @transformation = @ifc_total_transformation * self.placementrelto.ifc_total_transformation.inverse
      else
        # puts 'no placementrelto for object'
        @transformation = @ifc_total_transformation
      end
        
      # set relativeplacement
      self.relativeplacement = IfcAxis2Placement3D.new( @ifc_model, @transformation )
      self.relativeplacement.location = IfcCartesianPoint.new( @ifc_model, @transformation.origin )
      self.relativeplacement.axis = IfcDirection.new( @ifc_model, @transformation.zaxis )
      self.relativeplacement.refdirection = IfcDirection.new( @ifc_model, @transformation.xaxis )
    
    end
  end # module IfcLocalPlacement_su
end # module BimTools
