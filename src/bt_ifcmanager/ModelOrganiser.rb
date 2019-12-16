#  export.rb
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
  module IfcManager
    
    # class that walks the sketchup model and returns an Array containing
    # objects ordered for IFC export
    class ModelOrganiser
      attr_accessor :ifc_structure
      
      include IFC2X3
      
      def initialize( model )
        total_transformation = Geom::Transformation.new
        
        project = IfcProxyObject.new(model, total_transformation)
        site = IfcProxyObject.new(nil, total_transformation)
        building = IfcProxyObject.new(nil, total_transformation)
        storey = IfcProxyObject.new(nil, total_transformation)
        
        h_objects = get_instances( model.entities, total_transformation )
        
        @sites = Array.new
        @buildings = Array.new
        @storeys = Array.new
        @spaces = Array.new
        
        @ifc_structure = organise_model( h_objects)
        
        total = Hash.new
        total[project] = @sites
        total[project] = @sites
        total[project] = @sites
        total[project] = @sites
        
        
      end # def initialize
    
      # returns a Hash containing objects for all component instances in the model
      def get_instances( entities, total_transformation )
        h_objects = Hash.new
        entities.each do | ent |
          if ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
            
            # find IfcType
            begin
              # if classification is set, then that's the entity
              classification = definition.get_attribute("AppliedSchemaTypes", "IFC 2x3")
              require_relative File.join('IFC2X3', classification << ".rb")
              obj = eval(classification)
            rescue
              # if no classification AND parent is a IfcSpatialStructureElement then entity is IfcBuildingElementProxy
              if parent_ifc.is_a?(IfcSpatialStructureElement)
                obj = IfcBuildingElementProxy
              end
            end
            ##############################
            # obj = obj.new(step_writer, ent, total_transformation) ???
            # obj.total_transformation = total_transformation ???
            ########################
            h_objects[obj] = get_instances( obj.su_entities, obj.total_transformation )
          end
        end
        #unless h_objects.length==0
          return h_objects
        #end
      end # get_instances
    
      def organise_model( h_objects)        
        h_objects.each do | obj, h_sub_objects |
          type = obj.su_definition.get_attribute 'AppliedSchemaTypes', 'IFC 2x3'
          case type
          when 'IfcSite'
            @sites << h_objects.delete( obj )
          when 'IfcBuilding'
            @buildings << h_objects.delete( obj )
          when 'IfcBuildingStorey'
            @storeys << h_objects.delete( obj )
          when 'IfcSpace'
            @spaces << h_objects.delete( obj )
          end
          organise_model( h_sub_objects )
        end
        #unless h_objects.length==0
          return h_objects
        #end
      end # organise_model
    end # class ModelOrganiser
    
    
    class IfcProxyObject
      attr_accessor :su_instance, :ifc_type, :total_transformation, :su_entities, :su_definition
      def initialize( su_instance=nil, transformation )
        @su_instance = su_instance
        @ifc_type = su_instance.definition.get_attribute 'AppliedSchemaTypes', 'IFC 2x3'
        @total_transformation = su_instance.transformation * transformation
        @su_entities = su_instance.definition.entities
        @su_definition = su_instance.definition
      end # def initialize
      
    end # class IfcProxyObject
  end # module IfcManager
end # module BimTools
org = BimTools::IfcManager::ModelOrganiser.new(Sketchup.active_model)
org.inspect