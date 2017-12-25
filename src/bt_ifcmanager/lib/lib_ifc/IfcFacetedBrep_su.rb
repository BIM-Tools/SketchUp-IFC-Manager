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
        
        ifcclosedshell = IFC2X3::IfcClosedShell.new( ifc_model, su_faces )
        self.outer = ifcclosedshell
        
        faces = Array.new
        vertices = Hash.new
        su_faces.each do |ent|
          if ent.is_a? Sketchup::Face
            ent.vertices.each do |vert|
              unless vertices[vert]
                vertices[vert] = IFC2X3::IfcCartesianPoint.new( ifc_model, vert.position.transform(su_transformation))
              end
            end
            face = IFC2X3::IfcFace.new( ifc_model )
            face.bounds = IfcManager::Ifc_Set.new()
            faces << face
            
            
            # collect all loops/bounds for su face
            ent.loops.each do | loop |
              points = Array.new
              
              # differenciate between inner and outer loops/bounds
              if loop == ent.outer_loop
                bound = IFC2X3::IfcFaceOuterBound.new( ifc_model )
              else
                bound = IFC2X3::IfcFaceBound.new( ifc_model )
              end
              
              # add loop/bound to face
              face.bounds.add bound
              loop.vertices.each do |vert|
                points << vertices[vert]
              end
              polyloop = IFC2X3::IfcPolyLoop.new( ifc_model )
              bound.bound = polyloop
              bound.orientation = '.T.' # (?) always true?
              polyloop.polygon = IfcManager::Ifc_Set.new( points )
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
