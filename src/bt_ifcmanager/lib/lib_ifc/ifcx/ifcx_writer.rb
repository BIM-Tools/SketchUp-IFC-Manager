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
require_relative '../../../utils/uuid5'

module BimTools
  module IfcManager
    class IfcXWriter
      def initialize(ifc_model)
        @ifc_model = ifc_model
        @ifc_module = ifc_model.ifc_module
      end

      def write(file_path)
        json_data = {
          header: create_header_section(file_path),
          imports: create_imports_section,
          schemas: create_schemas_section,
          data: create_data_section
        }
        json_data = remove_null_values(json_data)
        formatted_json = format_json(json_data)
        File.open(file_path, 'w') do |file|
          file.write(formatted_json)
        end
      end

      private

      def format_json(obj)
        # Pretty-print as usual
        pretty = JSON.pretty_generate(obj, indent: '  ')

        # Render empty objects as {} on one line
        pretty.gsub!(/\{\s*\}/, '{}')

        # Collapse arrays of numbers to one line
        array_pattern = /\[\s*(?:-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\s*,?\s*)+\]/m
        pretty.gsub!(array_pattern) do |match|
          numbers = match.scan(/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/)
          "[#{numbers.join(', ')}]"
        end

        # Collapse arrays of arrays of numbers to one line
        # This regex matches [ [ ... ], [ ... ], ... ] with any whitespace/indentation
        array_of_arrays_pattern = /\[\s*(\[\s*-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?:\s*,\s*-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)*\s*\]\s*,?\s*){2,}\]/m
        pretty.gsub!(array_of_arrays_pattern) do |match|
          # Find all sub-arrays
          arrays = match.scan(/\[\s*-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?:\s*,\s*-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)*\s*\]/)
          "[#{arrays.join(', ')}]"
        end

        pretty
      end

      def create_header_section(file_path)
        time = Time.now
        timestamp = time.strftime('%Y-%m-%dT%H:%M:%S')
        id = File.basename(file_path)
        version_number = Sketchup.version_number / 100_000_000.floor
        originating_system = "SketchUp 20#{version_number} (#{Sketchup.version})"
        authorization = 'None'
        author = 'On-Track'

        # {
        #   file_description: {
        #     description: "ViewDefinition [#{get_mvd}]",
        #     implementation_level: '2;1'
        #   },
        #   file_name: {
        #     name: IfcManager::Types.replace_char(File.basename(file_path)),
        #     time_stamp: timestamp,
        #     author: author,
        #     organization: '',
        #     preprocessor_version: "IFC-manager for SketchUp (#{VERSION})",
        #     originating_system: originating_system,
        #     authorization: authorization
        #   },
        #   file_schema: Settings.ifc_version_compact
        # }
        {
          id: id,
          ifcxVersion: 'ifcx_alpha',
          dataVersion: '1.0.0',
          author: author,
          timestamp: timestamp # Time.now.to_s
        }
      end

      def create_imports_section
        [
          { "uri": 'https://ifcx.dev/@standards.buildingsmart.org/ifc/core/ifc@v5a.ifcx' },
          { "uri": 'https://ifcx.dev/@standards.buildingsmart.org/ifc/core/prop@v5a.ifcx' },
          { "uri": 'https://ifcx.dev/@standards.buildingsmart.org/ifc/ifc-mat/ifc-mat@v1.0.0.ifcx' },
          { "uri": 'https://ifcx.dev/@openusd.org/usd@v1.ifcx' },
          { "uri": 'https://ifcx.dev/@nlsfb/nlsfb@v1.ifcx' }
        ]
      end

      def create_schemas_section
        {
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

        project_objects = [{
          # comment: 'IFC project root',
          path: IfcManager::Utils.create_uuid5(project_name, project_uuid),
          children: { project_name => project_uuid }
        }, {
          path: project_uuid,
          attributes: {
            "bsi::ifc::class": {
              code: 'IfcProject',
              uri: 'https://identifier.buildingsmart.org/uri/buildingsmart/ifc/4.3/class/IfcProject'
            }
          }
        }]

        data_section = @ifc_model.ifc_objects.select do |obj|
          obj.is_a?(@ifc_module::IfcProject) ||
            obj.is_a?(@ifc_module::IfcMaterial) ||
            obj.is_a?(@ifc_module::IfcProduct) ||
            obj.is_a?(@ifc_module::IfcStyledItem) ||
            obj.is_a?(@ifc_module::IfcSurfaceStyle) ||
            obj.is_a?(@ifc_module::IfcTypeProduct) ||
            obj.is_a?(@ifc_module::IfcTriangulatedFaceSet) ||
            obj.is_a?(@ifc_module::IfcLocalPlacement) ||
            obj.is_a?(@ifc_module::IfcRelAssociatesMaterial) ||
            obj.is_a?(@ifc_module::IfcRelDefinesByProperties) ||
            obj.is_a?(@ifc_module::IfcClassificationReference)
        end.flat_map do |obj|
          result = obj.ifcx
          result.is_a?(Array) ? result : [result]
        end

        project_objects + data_section
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
