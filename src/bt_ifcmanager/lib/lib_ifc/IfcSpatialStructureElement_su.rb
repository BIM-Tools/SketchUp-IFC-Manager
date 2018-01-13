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


module BimTools
  module IfcSpatialStructureElement_su
    @relating_object = nil
    @related_objects = nil
    attr_accessor :relating_object, :related_objects
    def initialize(ifc_model, sketchup)
      
      # set default CompositionType
      self.compositiontype = ".ELEMENT."
      
      super
    end # def ifcspatialstructureelement_su
      
    # relating_object must be a IfcRelAggregates
    def relating_object=(obj)
      @relating_object = obj
      return @relating_object
    end
    
    # relating_object must be a IfcRelContainedInSpatialStructure
    def related_objects=(obj)
      @related_objects = obj
      return @related_objects
    end
    
    # def related_objects
    #   return @related_objects
    # end
      
  end # module IfcSpatialStructureElement
end # module BimTools