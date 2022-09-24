#  IfcFacetedBrep_su.rb
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

require_relative 'ifc_types'

module BimTools
  module IfcFacetedBrep_su
    
    
    def initialize( ifc_model, su_faces, su_transformation )
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module
      ifcclosedshell = @ifc::IfcClosedShell.new( ifc_model, su_faces )
      @ifc_model = ifc_model
      @su_transformation = su_transformation
      @outer = ifcclosedshell
      @vertices = Hash.new

      # multiply all transformation values to see if the component is flipped
      if @su_transformation.xaxis * @su_transformation.yaxis % @su_transformation.zaxis < 0
        @flipped = false
      else
        @flipped = true
      end

      faces = su_faces.map { |face| add_face(face) }
      if faces.length != 0
        ifcclosedshell.cfsfaces = IfcManager::Types::Set.new( faces )
      end
    end
    def add_face(su_face)
      create_points(su_face)
      face = @ifc::IfcFace.new( @ifc_model )
      bounds = su_face.loops.map{|loop| create_loop(loop)}
      face.bounds = IfcManager::Types::Set.new(bounds)
      return face
    end
    def create_loop(loop)
        
      # differenciate between inner and outer loops/bounds
      if loop.outer?
        bound = @ifc::IfcFaceOuterBound.new( @ifc_model )
      else
        bound = @ifc::IfcFaceBound.new( @ifc_model )
      end

      points = loop.vertices.map{|vert| @vertices[vert]}
      polyloop = @ifc::IfcPolyLoop.new( @ifc_model )
      bound.bound = polyloop
      bound.orientation = @flipped
      polyloop.polygon = IfcManager::Types::List.new( points )
      return bound
    end
    def create_points(su_face)
      vertices = su_face.vertices
      vert_count = vertices.length
      i = 0
      while i < vert_count
        unless @vertices[vertices[i]]
          position = vertices[i].position.transform(@su_transformation)
          @vertices[vertices[i]] = @ifc::IfcCartesianPoint.new( @ifc_model, position)
        end
        i += 1
      end
    end
  end
end
