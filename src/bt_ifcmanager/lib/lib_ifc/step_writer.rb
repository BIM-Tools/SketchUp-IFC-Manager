#  step_writer.rb
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

# create new ISO-10303-21/STEP object (the STEP object should do the formatting of the entire file, including header)

module BimTools
 module IfcManager
  class IfcStepWriter
    attr_reader :su_model
    attr_accessor :ifc_objects, :owner_history, :representationcontexts, :materials, :layers, :classifications, :classificationassociations #, :site, :building, :buildingstorey
    def initialize( ifc_model, file_schema, file_description, file_path, sketchup_objects=nil )
      @ifc_model = ifc_model
      
      step_objects = get_step_objects( file_schema, file_description, sketchup_objects )
      write( file_path, step_objects )
    end # def initialize
    
    def get_step_objects( file_schema, file_description, sketchup_objects )
      step_objects = Array.new
      step_objects << 'ISO-10303-21'
      step_objects.concat( create_header_section( file_schema, file_description ) )
      step_objects.concat( create_data_section( sketchup_objects ) )
      step_objects << 'END-ISO-10303-21'
      return step_objects
    end # get_step_objects
    
    def create_header_section( file_schema, file_description )
    
      # get timestamp
      time = Time.new
      timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
      
      # get originating_system
      originating_system = "SketchUp"
      if Sketchup.is_pro?
        originating_system = originating_system << " Pro"
      end
      number = Sketchup.version_number/100000000.floor
      originating_system = originating_system << " 20" << number.to_s
      originating_system = originating_system << " (" << Sketchup.version << ")"
          
      step_objects = Array.new
      step_objects << 'HEADER'
      step_objects << "FILE_DESCRIPTION (('ViewDefinition [CoordinationView]'), '2;1')"
      step_objects << "FILE_NAME ('', '#{timestamp}', (''), (''), 'IFC-manager for SketchUp (#{VERSION})', '#{originating_system}', '')"
      step_objects << "FILE_SCHEMA (('IFC2X3'))"
      step_objects << 'ENDSEC'
      return step_objects
    end # def create_header_section
    
    def create_data_section( sketchup_objects )
      
      ifc_objects = @ifc_model.ifc_objects()
      
      step_objects = Array.new
      step_objects << 'DATA'
      
      # skip if there are no entities
      if ifc_objects
        ifc_objects.each do | ifc_object |
          step_objects << ifc_object.step()
        
        ################################################################################
        # row id must be defined inside of the ifc object as "id" for step and ifcxml! #
        ################################################################################
        
        end
      end
      step_objects << 'ENDSEC'
      return step_objects
    end # def create_data_section
    
    def write( file_path, step_objects )
      file = File.open(file_path, "w:ISO-8859-1") #"w") #
      step_objects.each do | object |
        file.write object << ";\n"
      end
      file.close
    end # def write
    
  end # class IfcStepWriter
 end # module IfcManager
end # module BimTools
