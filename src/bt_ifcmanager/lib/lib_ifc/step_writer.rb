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

require_relative 'ifc_types'

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
                             mvd = case Settings.ifc_version
                                   when 'IFC 2x3'
                                     'CoordinationView_V2.0'
                                   when 'IFC 4'
                                     'ReferenceView_V1.2'
                                   else
                                     'ReferenceView'
                                   end
                             #  export_options = @ifc_model.options.map { |k, v| "'Option [#{k}: #{v}]'" }.join(",\n")
                             #  "(\n'ViewDefinition [#{mvd}]',\n#{export_options}\n)"
                             "('ViewDefinition [#{mvd}]')"
                           else
                             @file_description
                           end
        "FILE_DESCRIPTION(#{file_description},'2;1')"
      end

      def get_file_name(file_path, time)
        timestamp = time.strftime('%Y-%m-%dT%H:%M:%S')
        sketchup_version = Sketchup.version_number / 100_000_000.floor
        preprocessor_version = "Sketchup-IFC-manager #{VERSION} / SketchUp 20#{sketchup_version} (#{Sketchup.version})"
        originating_system = "BIM_Tools - Sketchup_IFC_manager - #{VERSION}"
        authorization = 'None'
        "FILE_NAME('#{IfcManager::Types.replace_char(File.basename(file_path))}','#{timestamp}',(''),(''),'#{preprocessor_version}','#{originating_system}','#{authorization}')"
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
        max_chunk_size = 10_000_000

        if File.extname(file_path).downcase == '.ifczip'
          BimTools::Zip.write_zip64_support = true # Enable ZIP64 for large files
          file_name = File.basename(file_path, File.extname(file_path)) << '.ifc'
          BimTools::Zip::OutputStream.open(file_path) do |zos|
            zos.put_next_entry(file_name)
            step_objects.each do |step_object|
              zos.puts step_object.encode('iso-8859-1') + ";\n"
            end

            # Write textures to a temporary directory and add them to the ZIP file
            Dir.mktmpdir('Sketchup-IFC-Manager-textures-') do |directory|
              texture_file_names = write_textures(@ifc_model, directory)
              texture_file_names.each do |texture_file_name|
                file = File.join(directory, texture_file_name)
                zos.put_next_entry File.basename(file)
                zos << File.binread(file)
              end
            end
          end
        else
          begin
            File.open(file_path, 'w:ISO-8859-1') do |file|
              current_chunk = String.new
              step_objects.each do |step_object|
                line = step_object + ";\n"
                if (current_chunk.size + line.size) > max_chunk_size
                  file.write(current_chunk)
                  current_chunk = String.new
                end
                current_chunk << line
              end
              file.write(current_chunk) unless current_chunk.empty? # Write remaining data
            end

            # Write textures to the target directory
            write_textures(@ifc_model, File.dirname(file_path))
          rescue SystemCallError => e
            message = "IFC Manager is unable to save the file: #{e.message}"
            puts message
            UI.messagebox(message, MB_OK)
            raise StandardError, message
          rescue StandardError => e
            message = "IFC Manager is unable to save the file: #{e.message}"
            puts message
            UI.messagebox(message, MB_OK)
            raise StandardError, message
          end
        end
      end

      # Writes the textures associated with the materials in the given IFC model to the specified directory.
      #
      # Parameters:
      # - ifc_model: The IFC model containing the materials and textures.
      # - directory: The directory where the textures will be written.
      #
      # Returns:
      # An array of filenames representing the written textures.
      def write_textures(ifc_model, directory)
        return [] unless ifc_model.textures

        # We cannot use TextureWriter.write_all because it only loads textures from objects, not materials directly.
        file_names = []
        ifc_model.materials.each_key do |material|
          next unless material && material.texture

          texture_file_name = File.basename(material.texture.filename)
          texture_file = File.join(directory, texture_file_name)
          material.texture.write(texture_file)
          file_names << texture_file_name
        end
        file_names
      end
    end
  end
end
