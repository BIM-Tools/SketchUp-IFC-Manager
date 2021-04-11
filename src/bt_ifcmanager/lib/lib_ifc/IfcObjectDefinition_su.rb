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
    
    
    ##
    # Add an element for which this element is the spatial container
    # Like a wall thats contained in a building

    def add_contained_element( object )
    
      # if no contains_elements exists, create one
      unless @contains_elements
        @contains_elements = BimTools::IFC2X3::IfcRelContainedInSpatialStructure.new(@ifc_model)
        @contains_elements.relatingstructure= self
        @contains_elements.relatedelements = BimTools::IfcManager::Ifc_Set.new()
      end
      
      # add child object
      @contains_elements.relatedelements.add( object )
    end # def add_contained_element
    

    ##
    # Add an object from which this element is decomposed
    # Like a building is decomposed into multiple buildingstoreys
    # Or a curtainwall is decomposed into muliple members/plates
    
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
          BimTools::IfcManager::add_export_message("Created default IfcSite")
          @default_related_object = BimTools::IFC2X3::IfcSite.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "default site" )
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
          BimTools::IfcManager::add_export_message("Created default IfcBuilding")
          @default_related_object = BimTools::IFC2X3::IfcBuilding.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "default building" )
          @default_related_object.description = BimTools::IfcManager::IfcText.new( "Description of Default Building" )
          parent_objectplacement = @objectplacement
        when BimTools::IFC2X3::IfcBuilding
          BimTools::IfcManager::add_export_message("Created default IfcBuildingStorey")
          @default_related_object = BimTools::IFC2X3::IfcBuildingStorey.new( @ifc_model )
          @default_related_object.name = BimTools::IfcManager::IfcLabel.new( "default building storey" )
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
  end # module IfcObjectDefinition_su
end # module BimTools
