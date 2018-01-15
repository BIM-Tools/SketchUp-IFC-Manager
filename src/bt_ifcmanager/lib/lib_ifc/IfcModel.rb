#  IfcModel.rb
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
require_relative 'IfcLabel.rb'
require_relative 'IfcText.rb'
require_relative 'ObjectCreator.rb'
require_relative 'step_writer.rb'

require_relative File.join('IFC2X3', 'IfcOwnerHistory.rb')
require_relative File.join('IFC2X3', 'IfcPersonAndOrganization.rb')
require_relative File.join('IFC2X3', 'IfcPerson.rb')
require_relative File.join('IFC2X3', 'IfcOrganization.rb')
require_relative File.join('IFC2X3', 'IfcApplication.rb')

require_relative File.join('IFC2X3', 'IfcProject.rb')
require_relative File.join('IFC2X3', 'IfcCartesianPoint.rb')
require_relative File.join('IFC2X3', 'IfcDirection.rb')

require_relative File.join('IFC2X3', 'IfcGeometricRepresentationContext.rb')

module BimTools
 module IfcManager
  class IfcModel
    
    include IFC2X3
    
    # (?) possible additional methods:
    # - get_ifc_objects(hash ifc->su)
    # - get_su_objects(hash su->ifc)
    # - add_su_object
    # - add_ifc_object
    
    attr_accessor :owner_history, :representationcontext, :layers, :materials, :classifications, :classificationassociations
    attr_reader :su_model, :project, :ifc_objects, :export_summary
    
    # creates an IFC model based on given su model
    # (?) could be enhanced to also accept other sketchup objects
    def initialize( su_model )
      @su_model = su_model
      @ifc_id = 0
      @export_summary = Hash.new
      
      # create collections for materials and layers
      @materials = Hash.new
      @layers = Hash.new
      @classifications = Array.new
      
      # create empty array that will contain all IFC objects
      @ifc_objects = Array.new
      
      # create IfcOwnerHistory for all IFC objects
      @owner_history = create_ownerhistory()
      
      # create new IfcProject
      @project = create_project( su_model )
      
      # create IfcGeometricRepresentationContext for all IFC geometry objects
      @representationcontext = create_representationcontext()
        
      @project.representationcontexts = IfcManager::Ifc_Set.new([@representationcontext])
      
      # create IFC objects for all su instances
      create_ifc_objects( su_model )
    end # def initialize
    
    # add object to ifc_objects array
    def add( ifc_object )
      @ifc_objects << ifc_object
      return new_id()
    end # def add
    
    def new_id()
      @ifc_id += 1
    end # def new_id
    
    # write the IfcModel to given filepath
    # (?) could be enhanced to also accept multiple ifc types like step / ifczip / ifcxml
    # (?) could be enhanced with export options hash
    def export( file_path )
      IfcStepWriter.new( self, 'file_schema', 'file_description', file_path, @su_model )
      
    end # def export
    
    # add object class name to export summary
    def summary_add( class_name )
      if @export_summary[class_name]
        @export_summary[class_name] += 1
      else
        @export_summary[class_name] = 1
      end
    end
    
    # retrieve the corresponding su instance for the given ifc object
    def get_ifc_object( su_object )
      
    end # def get_ifc_object
    
    # retrieve the corresponding ifc object for the given su instance
    def get_su_object( ifc_object )
      
    end # def get_su_object
    
    # create new IfcProject
    def create_project( su_model )
      project = IfcProject.new(self)
      project.name = BimTools::IfcManager::IfcLabel.new( su_model.name )
      project.description = BimTools::IfcManager::IfcText.new( su_model.description )
      return project
    end # def create_project
    
    # Create new IfcOwnerHistory
    def create_ownerhistory()
      owner_history = IfcOwnerHistory.new( self )
      owner_history.owninguser = IfcPersonAndOrganization.new( self )
      owner_history.owninguser.theperson = IfcPerson.new( self )
      owner_history.owninguser.theperson.familyname = BimTools::IfcManager::IfcLabel.new( "" )
      owner_history.owninguser.theorganization = IfcOrganization.new( self )
      owner_history.owninguser.theorganization.name = BimTools::IfcManager::IfcLabel.new( "BIM-Tools" )
      owner_history.owningapplication = IfcApplication.new( self )
      owner_history.owningapplication.applicationdeveloper = owner_history.owninguser.theorganization
      owner_history.owningapplication.version = "'2.0'"
      owner_history.owningapplication.applicationfullname = "'IFC manager for sketchup'"
      owner_history.owningapplication.applicationidentifier = "'su_ifcmanager'"
      owner_history.changeaction = '.ADDED.'
      owner_history.creationdate = Time.now.to_i.to_s
      return owner_history
    end # def set_owner_history
    
    # Create new IfcGeometricRepresentationContext
    def create_representationcontext()
      representationcontext = IfcGeometricRepresentationContext.new( self )
      representationcontext.contexttype = "'Model'"
      representationcontext.coordinatespacedimension = '3'
      representationcontext.worldcoordinatesystem = IfcAxis2Placement3D.new( self )
      representationcontext.worldcoordinatesystem.location = IfcCartesianPoint.new( self )
      representationcontext.worldcoordinatesystem.location.coordinates = '(0., 0., 0.)'
      representationcontext.truenorth = IfcDirection.new( self )
      representationcontext.truenorth.directionratios = IfcManager::Ifc_Set.new(['0., 1., 0.'])
      return representationcontext
    end # def create_representationcontext
    
    # create IFC objects for all su instances
    def create_ifc_objects( sketchup_objects )
      if sketchup_objects.is_a? Sketchup::Model
        sketchup_objects.entities.each do | ent |
          if ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
          
            # skip hidden objects
            #(?) add option to export hidden objects
            unless ent.hidden?
              transformation = Geom::Transformation.new
              ObjectCreator.new( self, ent, transformation, @project )
            end
            
            # require_relative File.join('IFC2X3', 'IfcBuildingElementProxy.rb')
            # entity = IfcBuildingElementProxy.new( self, ent )
            # building_storey_container.relatedelements.add( entity )
          end
        end
      end
      
      return ifc_objects
    end # create_ifc_objects
  end # class IfcModel
 end # module IfcManager
end # module BimTools
