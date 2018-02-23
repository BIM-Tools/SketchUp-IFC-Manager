#  ObjectCreator.rb
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


# # parent_shape_representation = shape representation linked to the parent_ifc (containing the brep's)
# transformation = the sketchup transformation object that translates back to the parent_ifc

# indexer = row numbering object (temporarily replaced by the complete ifc_model object)
# su_instance = sketchup component instance or group
# su_total_transformation = sketchup total transformation from model root to this instance placement
# parent_ifc = ifc entity above this one in the hierarchy
# parent_space = ifc space above this one in the hierarchy
# parent_buildingstorey = ifc buildingstorey above this one in the hierarchy
# parent_building = ifc building above this one in the hierarchy
# parent_site = ifc site above this one in the hierarchy

require_relative 'IfcLengthMeasure.rb'
require_relative File.join('IFC2X3', 'IfcSpatialStructureElement.rb')
require_relative File.join('IFC2X3', 'IfcSite.rb')
require_relative File.join('IFC2X3', 'IfcBuilding.rb')
require_relative File.join('IFC2X3', 'IfcBuildingStorey.rb')
require_relative File.join('IFC2X3', 'IfcBuildingElementProxy.rb')
require_relative File.join('IFC2X3', 'IfcLocalPlacement.rb')
require_relative File.join('IFC2X3', 'IfcFacetedBrep.rb')
require_relative File.join('IFC2X3', 'IfcStyledItem.rb')

module BimTools
 module IfcManager

  # checks the current definition for ifc objects, and calls itself for all nested items
  class ObjectCreator
    
    # def initialize(ifc_model, su_instance, container, containing_entity, parent_ifc, transformation_from_entity, transformation_from_container, site=nil, site_container=nil, building=nil, building_container=nil, building_storey=nil, building_storey_container=nil)
    def initialize(ifc_model, su_instance, su_total_transformation, parent_ifc, parent_site=nil, parent_building=nil, parent_buildingstorey=nil, parent_space=nil, su_material=nil)
      @skip_entity = false
      definition = su_instance.definition   
      su_material = su_instance.material if su_instance.material      
      ent_type_name = definition.get_attribute("AppliedSchemaTypes", "IFC 2x3")
      
      # check if entity_type is part of the entity list that needs exporting
      # also continue if NOT an IFC entity but the parent object IS an entity
      if ifc_model.options[:ifc_entities] == false || ifc_model.options[:ifc_entities].include?( ent_type_name ) || ( ent_type_name.nil? && parent_ifc.is_a?(BimTools::IFC2X3::IfcProduct) && !parent_ifc.is_a?(BimTools::IFC2X3::IfcSpatialStructureElement))
        
        # Create IFC entity based on the IFC classification in sketchup
        begin
          require_relative File.join('IFC2X3', ent_type_name)
          entity_type = eval("BimTools::IFC2X3::#{ent_type_name}")
          
          # merge this project with the default project
          #(?) what if there are multiple projects defined?
          if entity_type == BimTools::IFC2X3::IfcProject
            ifc_entity = ifc_model.project
          else
            ifc_entity = entity_type.new(ifc_model, su_instance)
          end
        rescue
          
          # If not classified as IFC in sketchup AND the parent is an IfcSpatialStructureElement then this is an IfcBuildingElementProxy
          if parent_ifc.is_a?(BimTools::IFC2X3::IfcSpatialStructureElement) || parent_ifc.is_a?(BimTools::IFC2X3::IfcProject)
            ifc_entity = BimTools::IFC2X3::IfcBuildingElementProxy.new(ifc_model, su_instance)
          else # this instance is pure geometry, ifc_entity = nil
            ifc_entity = nil
          end
        end
      else
        
        # mark this entity's geometry to be skipped
        @skip_entity = true
      end
      
      # find the correct parent in the spacialhierarchy
      if ifc_entity.is_a? BimTools::IFC2X3::IfcProduct
        
        # check the element type and set the correct parent in the spacialhierarchy
        case ifc_entity.class.to_s
        when 'BimTools::IFC2X3::IfcSite'
          parent_ifc = ifc_model.project
          next_parent_site = ifc_entity
        when 'BimTools::IFC2X3::IfcBuilding'
          if parent_site.nil? # create new site
            parent_site = ifc_model.project.get_default_related_object
          end
          parent_ifc = parent_site
          next_parent_building = ifc_entity
        when 'BimTools::IFC2X3::IfcBuildingStorey'
          if parent_building.nil? # create new building
            if parent_site.nil? # create new site
              parent_site = ifc_model.project.get_default_related_object
            end
            parent_building = parent_site.get_default_related_object
          end
          parent_ifc = parent_building
          next_parent_buildingstorey = ifc_entity
        when 'BimTools::IFC2X3::IfcSpace'
          if parent_buildingstorey.nil? # create new buildingstorey
            if parent_building.nil? # create new building
              if parent_site.nil? # create new site
                parent_site = ifc_model.project.get_default_related_object
              end
              parent_building = parent_site.get_default_related_object
            end
            parent_buildingstorey = parent_building.get_default_related_object
          end
          parent_space = ifc_entity
          parent_ifc = parent_buildingstorey
        else # 'normal' product, no IfcSpatialStructureElement
          if parent_space
            parent_ifc = parent_space
          else
          
            # (!) Problem here is that an object is always added to the default container if it's defined before any other containers are found/created
            case parent_ifc.class.to_s
            when 'BimTools::IFC2X3::IfcProject'
              
              # check if this parent project contains 'non-default' sites
              # if this is the case then place ifc_entity directly into the first site (?) First site ok? or better use a new default site?
              # if not, then create a default site...
              if ifc_model.project.non_default_related_objects.length == 0 #   if no IfcSite defined
                parent_ifc = ifc_model.project.get_default_related_object #      parent is default site
                parent_site = parent_ifc
                if parent_ifc.non_default_related_objects.length == 0 #   if no IfcBuilding defined
                  parent_ifc = parent_ifc.get_default_related_object #      parent is default building
                  parent_building = parent_ifc
                  if parent_ifc.non_default_related_objects.length == 0 # if no IfcBuildingStorey defined
                    parent_ifc = parent_ifc.get_default_related_object #    parent is default buildingstorey
                    parent_buildingstorey = parent_ifc
                  end
                end
              else
                parent_ifc = parent_ifc.non_default_related_objects[0]
              end
            when 'BimTools::IFC2X3::IfcSite'
              
              # check if this parent site contains 'non-default' buildings
              # if this is the case then place ifc_entity directly into the site
              # if not, then create a default building as container for this site...
              
              if parent_ifc.non_default_related_objects.length == 0 #   if no IfcBuilding defined
                parent_ifc = parent_ifc.get_default_related_object #      parent is default building
                parent_building = parent_ifc
                if parent_ifc.non_default_related_objects.length == 0 # if no IfcBuildingStorey defined
                  parent_ifc = parent_ifc.get_default_related_object #    parent is default buildingstorey
                  parent_buildingstorey = parent_ifc
                end
              end
            when 'BimTools::IFC2X3::IfcBuilding'
              
              # check if this parent building contains 'non-default' buildingstoreys
              # if this is the case then place ifc_entity directly inside the building
              # if not, then create a default buildingstorey as container for this building
              
              if parent_ifc.non_default_related_objects.length == 0 # if no IfcBuildingStorey defined
                parent_ifc = parent_ifc.get_default_related_object #    parent is default buildingstorey
                parent_buildingstorey = parent_ifc
              end
            when 'BimTools::IFC2X3::IfcBuildingStorey'
              parent_buildingstorey = parent_ifc
            when 'BimTools::IFC2X3::IfcSpace'
              parent_space = parent_ifc
            
            # when parent is not a spacialstructureelement
            else
              if parent_buildingstorey.nil? # create new buildingstorey
                if parent_building.nil? # create new building
                  if parent_site.nil? # create new site
                    parent_site = ifc_model.project.get_default_related_object
                  end
                  parent_building = parent_site.get_default_related_object
                end
                parent_buildingstorey = parent_building.get_default_related_object
              end
              parent_ifc = parent_buildingstorey
            end
          end
          
          # add this element to the model
          parent_ifc.add_related_element( ifc_entity )
        end
        
        # add spacialstructureelements to the spacialhierarchy
        if ifc_entity.is_a? BimTools::IFC2X3::IfcSpatialStructureElement
          parent_ifc.add_related_object( ifc_entity )
        end
        ifc_entity.parent = parent_ifc
      end
      
      # calculate the total transformation
      su_total_transformation = su_total_transformation * su_instance.transformation
      
      # create objectplacement for ifc_entity
      # set objectplacement based on transformation
      if ifc_entity
        if parent_ifc.is_a?( BimTools::IFC2X3::IfcProject )
          parent_objectplacement = nil
        else
          parent_objectplacement = parent_ifc.objectplacement
        end
        
        # set object placement, except for the IfcProject which does not have an objectplacement
        unless ifc_entity.is_a?(BimTools::IFC2X3::IfcProject)
          ifc_entity.objectplacement = BimTools::IFC2X3::IfcLocalPlacement.new(ifc_model, su_total_transformation, parent_objectplacement )
        end
        
        # set elevation for buildingstorey
        # (?) is this the best place to define building storey elevation?
        # could be better set from within IfcBuildingStorey?
        if ifc_entity.is_a?( BimTools::IFC2X3::IfcBuildingStorey )
          elevation = ifc_entity.objectplacement.ifc_total_transformation.origin.z.to_mm
          ifc_entity.elevation = BimTools::IfcManager::IfcLengthMeasure.new( elevation )
        end
        
        #ifc_entity.objectplacement.set_transformation( 
        #unless parent_ifc.is_a?(BimTools::IFC2X3::IfcProject) # (?) check unnecessary?
        #  ifc_entity.objectplacement.placementrelto = parent_ifc.objectplacement
        #end
      end
      
      # if this SU object is not an IFC Entity then set the parent entity as Ifc Entity
      unless ifc_entity
        ifc_entity = parent_ifc
      end
      
      # calculate the local transformation
      # if the SU object if not an IFC entity, then BREP needs to be transformed with SU object transformation
      
      
      # corrigeren voor het geval beide transformties dezelfde verschaling hebben, die mag niet met inverse geneutraliseerd worden
      # er zou in de ifc_total_transformation eigenlijk geen verschaling mogen zitten.
      # wat mag er wel in zitten? wel verdraaiing en verplaatsing.
      
      if next_parent_site then parent_site = next_parent_site end
      if next_parent_building then parent_building = next_parent_building end
      if next_parent_buildingstorey then parent_buildingstorey = next_parent_buildingstorey end
      
      # find sub-objects (geometry and entities)
      faces = Array.new
      definition.entities.each do | ent |
        
        # skip hidden objects if skip-hidden option is set
        unless ifc_model.options[:hidden] == false && ent.hidden?
          case ent
          when Sketchup::Group, Sketchup::ComponentInstance
            # ObjectCreator.new( ifc_model, ent, container, containing_entity, parent_ifc, transformation_from_entity, transformation_from_container)
            ObjectCreator.new(ifc_model, ent, su_total_transformation, ifc_entity, parent_site, parent_building, parent_buildingstorey, parent_space, su_material)

          when Sketchup::Face
            unless @skip_entity
              faces << ent
            end
          end
        end
      end
      
      unless ifc_entity.is_a?(BimTools::IFC2X3::IfcProject) || parent_ifc.is_a?(BimTools::IFC2X3::IfcProject)
        brep_transformation = ifc_entity.objectplacement.ifc_total_transformation.inverse * su_total_transformation
      else
        brep_transformation = su_total_transformation
      end
      
      # create geometry from faces
      unless faces.empty?
        brep = BimTools::IFC2X3::IfcFacetedBrep.new( ifc_model, faces, brep_transformation )
        ifc_entity.representation.representations.first.items.add( brep )
        
        # if no material present, use material from first face?
        #if su_material.nil?
        #  su_material = faces[0].material unless faces[0].material.nil?
        #end
        
        # add color from su-object material, or a su_parent's
        BimTools::IFC2X3::IfcStyledItem.new( ifc_model, brep, su_material )
      end
    end # def initialize
  end # class ObjectCreator

 end # module IfcManager
end # module BimTools
