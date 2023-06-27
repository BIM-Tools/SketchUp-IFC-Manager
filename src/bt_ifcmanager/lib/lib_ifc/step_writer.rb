# frozen_string_literal: true

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
    require File.join(PLUGIN_ZIP_PATH, 'zip') unless defined? BimTools::Zip
    class IfcStepWriter
      attr_accessor :ifc_objects, :owner_history, :representationcontexts, :materials, :layers, :classifications, :classificationassociations # , :site, :building, :buildingstorey

      def initialize(ifc_model, file_schema = nil, file_description = nil)
        @ifc_model = ifc_model
        @file_schema = file_schema
        @file_description = file_description
      end

      def get_step_objects(file_path)
        time = Time.new
        step_objects = []
        step_objects << 'ISO-10303-21'
        step_objects.concat(create_header_section(file_path, time))
        step_objects.concat(create_data_section)
        step_objects << 'END-ISO-10303-21'
        step_objects
      end

      def create_header_section(file_path, time)
        step_objects = []
        step_objects << 'HEADER'
        step_objects << get_file_description
        step_objects << get_file_name(file_path, time)
        step_objects << get_file_schema
        step_objects << 'ENDSEC'
        step_objects
      end

      def get_file_description
        file_description = if @file_description.nil?
                             # get correct MVD for IFC version
                             mvd = if Settings.ifc_version_compact == 'IFC2X3'
                                     'CoordinationView_V2.0'
                                   else
                                     'ReferenceView_V1.2'
                                   end
                             export_options = @ifc_model.options.map { |k, v| "'Option [#{k}: #{v}]'" }.join(",\n")
                             "(\n#{export_options},\n'ViewDefinition [#{mvd}]'\n)"
                           else
                             @file_description
                           end
        "FILE_DESCRIPTION(#{file_description},'2;1')"
      end

      def get_file_name(file_path, time)
        timestamp = time.strftime('%Y-%m-%dT%H:%M:%S')
        version_number = Sketchup.version_number / 100_000_000.floor
        originating_system = "SketchUp 20#{version_number} (#{Sketchup.version})"
        "FILE_NAME('#{File.basename(file_path)}','#{timestamp}',(''),(''),'IFC-manager for SketchUp (#{VERSION})','#{originating_system}','')"
      end

      def get_file_schema
        file_schema = if @file_schema.nil?
                        "('#{Settings.ifc_version_compact}')"
                      else
                        @file_schema
                      end
        "FILE_SCHEMA(#{file_schema})"
      end

      def create_data_section
        step_objects = @ifc_model.ifc_objects.map(&:step)
        step_objects.unshift('DATA')
        step_objects << 'ENDSEC'
        step_objects
      end

      def write(file_path)
        step_objects = get_step_objects(file_path)
        if File.extname(file_path).downcase == '.ifczip'
          file_name = File.basename(file_path, File.extname(file_path)) << '.ifc'
          BimTools::Zip::OutputStream.open(file_path) do |zos|
            zos.put_next_entry(file_name)
            zos.puts (step_objects.join(";\n") << ';').encode('iso-8859-1')
            Dir.mktmpdir('Sketchup-IFC-Manager-textures-') do |dir|
              # Write textures to temp location
              if @ifc_model.textures && @ifc_model.textures.write_all(dir, false)
                puts('Texture files were successfully written.')
              end

              # add textures to zipfile
              Dir.foreach(dir) do |filename|
                next if ['.', '..'].include?(filename)

                file = File.join(dir, filename)
                zos.put_next_entry File.basename(file)
                zos << File.binread(file)
              end
            end
          end
        else
          begin
            File.open(file_path, 'w:ISO-8859-1') do |file|
              file.write(step_objects.join(";\n") << ';')
            end

            # Write textures to the ifc file location
            if @ifc_model.textures && @ifc_model.textures.write_all(File.dirname(file_path), false)
              puts('Texture files were successfully written.')
            end
            ''
          rescue SystemCallError => e
            message = "IFC Manager is unable to save the file: #{e.message}"
            puts message
            UI.messagebox(message, MB_OK)
            message
          rescue StandardError => e
            message = "IFC Manager is unable to save the file: #{e.message}"
            puts message
            UI.messagebox(message, MB_OK)
            message
          end
        end
      end
    end
  end
end
