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
        @decomposes = BimTools::IFC2X3::IfcRelAggregates.new(@ifc_model)
        @decomposes.relatingobject = self
        @decomposes.relatedobjects = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @decomposes.relatedobjects.add( object )
    end # def add_related_object
    
    def non_default_related_objects()
      if @decomposes
        return @decomposes.relatedobjects.items - [@default_related_object]
      else
        return Array.new
      end
    end
    
    # return the default child object
    def get_default_related_object
      unless @default_related_object
      
        # If it does not exist, then create
        case self
        when BimTools::IFC2X3::IfcProject
          puts 'add default site'
          @default_related_object = BimTools::IFC2X3::IfcSite.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Site" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Site" )

          # set geolocation
          if Sketchup.active_model.georeferenced?
            @default_related_object.set_latlong
            @default_related_object.reflatitude = @default_related_object.latitude
            @default_related_object.reflongitude = @default_related_object.longtitude
            @default_related_object.refelevation = @default_related_object.elevation
          end
          parent_objectplacement = nil
        when BimTools::IFC2X3::IfcSite
          puts 'add default building'
          @default_related_object = BimTools::IFC2X3::IfcBuilding.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Building" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Building" )
          parent_objectplacement = @objectplacement
        when BimTools::IFC2X3::IfcBuilding
          puts 'add default storey'
          @default_related_object = BimTools::IFC2X3::IfcBuildingStorey.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "Default Building Storey" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Building Storey" )
          parent_objectplacement = @objectplacement
        end
        
        @default_related_object.parent = self
        if parent_objectplacement
          transformation = parent_objectplacement.ifc_total_transformation
        else
          transformation = Geom::Transformation.new
        end
        @default_related_object.objectplacement = BimTools::IFC2X3::IfcLocalPlacement.new(@ifc_model, transformation, parent_objectplacement )
        
        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        # could be better set from within IfcBuildingStorey?
        if @default_related_object.is_a?( BimTools::IFC2X3::IfcBuildingStorey )
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
        @ifc_rel_contained_in_spatial_structure = BimTools::IFC2X3::IfcRelContainedInSpatialStructure.new(@ifc_model)
        @ifc_rel_contained_in_spatial_structure.relatingstructure= self
        @ifc_rel_contained_in_spatial_structure.relatedelements = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @ifc_rel_contained_in_spatial_structure.relatedelements.add( object )
    end # def add_related_object
  end # module IfcObjectDefinition_su
end # module BimTools
