#  IfcObjectDefinition_su.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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
# require_relative File.join('IFC2X3', 'IfcRelContainedInSpatialStructure.rb')
# require_relative File.join('IFC2X3', 'IfcRelAggregates.rb')

module BimTools
  module IfcObjectDefinition_su
    attr_accessor :decomposes, :default_related_object
    def initialize(ifc_model, sketchup)
      super
      @ifc_model = ifc_model
    end
    
    # Add an element for which this element is the spatial container
    # Like a wall thats contained in a building
    #
    def add_contained_element( object )
      unless @contains_elements
        @contains_elements = BimTools::IFC2X3::IfcRelContainedInSpatialStructure.new(@ifc_model)
        @contains_elements.relatingstructure= self
        @contains_elements.relatedelements = BimTools::IfcManager::Ifc_Set.new()
      end
      @contains_elements.relatedelements.add( object )
    end
    
    # Add an object from which this element is decomposed
    # Like a building is decomposed into multiple buildingstoreys
    # Or a curtainwall is decomposed into muliple members/plates
    #
    def add_related_object( object )
      unless @decomposes
        @decomposes = BimTools::IFC2X3::IfcRelAggregates.new(@ifc_model)
        @decomposes.relatingobject = self
        @decomposes.relatedobjects = BimTools::IfcManager::Ifc_Set.new()
      end
      @decomposes.relatedobjects.add( object )
    end
  end
end
