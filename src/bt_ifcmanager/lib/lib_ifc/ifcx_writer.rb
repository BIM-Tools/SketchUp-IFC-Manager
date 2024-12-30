# frozen_string_literal: true

#  ifcx_writer.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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

require 'json'

module BimTools
  module IfcManager
    class IfcXWriter
      def initialize(ifc_model)
        @ifc_model = ifc_model
        @ifc_module = ifc_model.ifc_module
      end

      def write(file_path)
        json_objects = remove_null_values(create_data_section)
        File.open(file_path, 'w') do |file|
          file.write(JSON.pretty_generate(json_objects))
        end
      end

      private

      def create_header_section(file_path)
        time = Time.now
        timestamp = time.strftime('%Y-%m-%dT%H:%M:%S')
        version_number = Sketchup.version_number / 100_000_000.floor
        originating_system = "SketchUp 20#{version_number} (#{Sketchup.version})"
        authorization = 'None'

        {
          file_description: {
            description: "ViewDefinition [#{get_mvd}]",
            implementation_level: '2;1'
          },
          file_name: {
            name: IfcManager::Types.replace_char(File.basename(file_path)),
            time_stamp: timestamp,
            author: '',
            organization: '',
            preprocessor_version: "IFC-manager for SketchUp (#{VERSION})",
            originating_system: originating_system,
            authorization: authorization
          },
          file_schema: Settings.ifc_version_compact
        }
      end

      def get_mvd
        case Settings.ifc_version
        when 'IFC 2x3'
          'CoordinationView_V2.0'
        when 'IFC 4'
          'ReferenceView_V1.2'
        else
          'ReferenceView'
        end
      end

      def create_data_section
        project_name = @ifc_model.project.name.value
        project_uuid = @ifc_model.project.globalid.ifcx

        project_object = {
          'def' => 'def',
          'type' => 'UsdGeom:Xform',
          'comment' => "definition of: #{project_name}",
          'name' => project_name,
          'inherits' => [
            "</#{project_uuid}>"
          ]
        }

        data_section = @ifc_model.ifc_objects.select do |obj|
          obj.is_a?(@ifc_module::IfcProject) ||
            obj.is_a?(@ifc_module::IfcMaterial) ||
            obj.is_a?(@ifc_module::IfcProduct) ||
            obj.is_a?(@ifc_module::IfcTriangulatedFaceSet) ||
            obj.is_a?(@ifc_module::IfcLocalPlacement) ||
            obj.is_a?(@ifc_module::IfcRelAssociatesMaterial) ||
            obj.is_a?(@ifc_module::IfcRelDefinesByProperties) ||
            obj.is_a?(@ifc_module::IfcShapeRepresentation)
        end.flat_map do |obj|
          puts obj.class
          result = obj.ifcx
          result.is_a?(Array) ? result : [result]
        end

        [project_object] + data_section
      end

      def remove_null_values(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            value = remove_null_values(v)
            h[k] = value unless value.nil?
          end
        when Array
          obj.map { |e| remove_null_values(e) }.compact
        else
          obj
        end
      end
    end
  end
end
