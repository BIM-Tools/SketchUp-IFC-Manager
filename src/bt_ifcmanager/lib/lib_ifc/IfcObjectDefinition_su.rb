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
require_relative File.join('IFC2X3', 'IfcRelContainedInSpatialStructure.rb')
require_relative File.join('IFC2X3', 'IfcRelAggregates.rb')

module BimTools
  module IfcObjectDefinition_su
    attr_reader :decomposes, :default_related_object
    
    include IFC2X3
    
    def initialize(ifc_model, sketchup)
      super
      @ifc_model = ifc_model
    end # def initialize
    
    def decomposes()
      return @decomposes
    end
    
    # add child object in the model hierarchy
    def add_related_object( object )
      
      # if no decomposes exists, create one
      unless @decomposes
        @decomposes = IfcRelAggregates.new(@ifc_model)
        @decomposes.relatingobject = self
        @decomposes.relatedobjects = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @decomposes.relatedobjects.add( object )
    end # def add_related_object
    
    # return the default child object
    def get_default_related_object
      unless @default_related_object
      
        # If it does not exist, then create
        case self
        when IfcProject
          puts 'add default site'
          @default_related_object = IfcSite.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Site" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Site" )
          parent_objectplacement = nil
        when IfcSite
          puts 'add default building'
          @default_related_object = IfcBuilding.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Building" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Building" )
          parent_objectplacement = self.objectplacement
        when IfcBuilding
          puts 'add default storey'
          @default_related_object = IfcBuildingStorey.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Building Storey" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Building Storey" )
          parent_objectplacement = self.objectplacement
        end
        
        @default_related_object.parent = self
        if parent_objectplacement
          transformation = parent_objectplacement.ifc_total_transformation
        else
          transformation = Geom::Transformation.new
        end
        @default_related_object.objectplacement = IfcLocalPlacement.new(@ifc_model, transformation, parent_objectplacement )
        
        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        # could be better set from within IfcBuildingStorey?
        if @default_related_object.is_a?( IfcBuildingStorey )
          elevation = @default_related_object.objectplacement.ifc_total_transformation.origin.z.to_mm
          @default_related_object.elevation = BimTools::IfcManager::IfcLengthMeasure.new( elevation )
        end
        
        # add new default object to the model hierarchy
        add_related_object( @default_related_object )
      end
      return @default_related_object
    end # def get_default_related_object
    
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
