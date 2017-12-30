#  IfcProject.rb
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
require_relative File.join('IFC2X3', 'IfcRelContainedInSpatialStructure.rb')
require_relative File.join('IFC2X3', 'IfcRelAggregates.rb')

module BimTools
  module IfcObjectDefinition_su
    
    include IFC2X3
    
    def initialize(ifc_model, sketchup)
      super
      @ifc_model = ifc_model
    end # def initialize
    
    # add child object in the model hierarchy
    def add_related_object( object )
      
      # if no ifc_rel_aggregates exists, create one
      unless @ifc_rel_aggregates
        @ifc_rel_aggregates = IfcRelAggregates.new(@ifc_model)
        @ifc_rel_aggregates.relatingobject = self
        @ifc_rel_aggregates.relatedobjects = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @ifc_rel_aggregates.relatedobjects.add( object )
    end # def add_related_object
    
    # add direct child object
    def add_related_element( object )
    
      # if no ifc_rel_contained_in_spatial_structure exists, create one
      unless @ifc_rel_contained_in_spatial_structure
        @ifc_rel_contained_in_spatial_structure = IfcRelContainedInSpatialStructure.new(@ifc_model)
        @ifc_rel_contained_in_spatial_structure.relatingstructure= self
        @ifc_rel_contained_in_spatial_structure.relatedelements = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @ifc_rel_contained_in_spatial_structure.relatedelements.add( object )
    end # def add_related_object
  end # module IfcObjectDefinition_su
end # module BimTools
