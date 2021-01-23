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

require_relative 'set.rb'
require_relative File.join('IFC2X3', 'IfcClosedShell.rb')
require_relative File.join('IFC2X3', 'IfcFace.rb')
require_relative File.join('IFC2X3', 'IfcFaceBound.rb')
require_relative File.join('IFC2X3', 'IfcFaceOuterBound.rb')
require_relative File.join('IFC2X3', 'IfcPolyLoop.rb')
require_relative File.join('IFC2X3', 'IfcCartesianPoint.rb')

module BimTools
  module IfcFacetedBrep_su
    def initialize( ifc_model, su_faces, su_transformation )
      super
      
      #if sketchup.is_a? Sketchup::ComponentDefinition
        
        ifcclosedshell = BimTools::IFC2X3::IfcClosedShell.new( ifc_model, su_faces )
        @outer = ifcclosedshell
        
        faces = Array.new
        vertices = Hash.new
        su_faces.each do |ent|
          if ent.is_a? Sketchup::Face
            ent.vertices.each do |vert|
              unless vertices[vert]
                vertices[vert] = BimTools::IFC2X3::IfcCartesianPoint.new( ifc_model, vert.position.transform(su_transformation))
              end
            end
            face = BimTools::IFC2X3::IfcFace.new( ifc_model )
            face.bounds = IfcManager::Ifc_Set.new()
            faces << face
            
            
            # collect all loops/bounds for su face
            ent.loops.each do | loop |
              points = Array.new
              
              # differenciate between inner and outer loops/bounds
              if loop.outer?
                bound = BimTools::IFC2X3::IfcFaceOuterBound.new( ifc_model )
              else
                bound = BimTools::IFC2X3::IfcFaceBound.new( ifc_model )
              end
              
              # add loop/bound to face
              face.bounds.add bound
              loop.vertices.each do |vert|
                points << vertices[vert]
              end
              # unless su_transformation.xaxis * su_transformation.yaxis * su_transformation.zaxis
                # points.reverse!
              # end
              ta = su_transformation.to_a
              ta.delete_at(3)
              ta.delete_at(7)
              ta.delete_at(11)
              ta.delete_at(12)
              ta.delete_at(13)
              ta.delete_at(14)
              ta.delete_at(15)
              # multiply all transformation values to see if the result is negative(and the component is flipped)
              # then reverse the face loop
              if su_transformation.xaxis * su_transformation.yaxis % su_transformation.zaxis < 0#su_transformation.to_a.reject(&:zero?).inject(:*) <0
                points.reverse!
              end
              
              # def self.get_vertex_order(positions, face_normal)
                # calculated_normal = (positions[1] - positions[0]).cross( (positions[2] - positions[0]) )
                # order = [0, 1, 2]
                # order.reverse! if calculated_normal.dot(face_normal) < 0
                # order
              # end
              polyloop = BimTools::IFC2X3::IfcPolyLoop.new( ifc_model )
              bound.bound = polyloop
              bound.orientation = '.T.' # (?) always true?
              polyloop.polygon = IfcManager::Ifc_List.new( points )
            end
          end
        end
        if faces.length != 0
          ifcclosedshell.cfsfaces = IfcManager::Ifc_Set.new( faces )
        end
      #end      
    end # def sketchup
  end # module IfcFacetedBrep_su
end # module BimTools
