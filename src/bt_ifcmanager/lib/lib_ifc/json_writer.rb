#  json_writer.rb
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

module BimTools
 module IfcManager
  class IfcJsonWriter
    attr_reader :su_model
    attr_accessor :ifc_objects, :owner_history, :representationcontexts, :materials, :layers, :classifications, :classificationassociations #, :site, :building, :buildingstorey
    def initialize( ifc_model, file_schema, file_description, file_path, sketchup_objects=nil )
      @ifc_model = ifc_model
      
      json_objects = Hash.new
      json_objects[:header] = create_header_section( file_path, file_schema, file_description )
      json_objects[:data] = create_data_section( sketchup_objects )

      write( file_path, json_objects )
    end # def initialize
    
    def create_header_section( file_path, file_schema, file_description )
      file_name = File.basename(file_path)
    
      # get timestamp
      time = Time.new
      timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
      
      # get originating_system
      originating_system = "SketchUp"
      if Sketchup.is_pro?
        originating_system = originating_system + " Pro"
      end
      number = Sketchup.version_number/100000000.floor
      originating_system = originating_system + " 20" + number.to_s
      originating_system = originating_system + " (" + Sketchup.version + ")"
      
      json_header = {
        :file_description => {
          :description => "ViewDefinition [CoordinationView]",
          :implementation_level => "2;1"
        },
        :file_name => {
          :name => file_name,
          :time_stamp => timestamp,
          :author => "",
          :organization => "",
          :preprocessor_version => "IFC-manager for SketchUp (#{VERSION})",
          :originating_system => originating_system,
          :authorization => ""
        },
        :file_schema => 'IFC2X3'
      }
      return json_header
    end # def create_header_section
    
    def create_data_section( sketchup_objects )
      
      ifc_objects = @ifc_model.ifc_objects()
      
      json_objects = Array.new
      
      # skip if there are no entities
      if ifc_objects
        ifc_objects.each do | ifc_object |
          if ifc_object.is_a?(BimTools::IFC2X3::IfcObjectDefinition)
            json_objects << ifc_object
          end
        end
      end
      return json_objects
      # return @ifc_model.project
    end # def create_data_section
    
    def write( file_path, json_objects )

      File.open(file_path, 'w') do |f|
        f.write(json_objects.to_json)
      end
    end # def write
    
  end # class IfcJsonWriter
 end # module IfcManager
end # module BimTools
