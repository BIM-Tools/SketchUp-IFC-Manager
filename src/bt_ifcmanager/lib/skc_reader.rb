# frozen_string_literal: true

#  loader.rb
#
#  Copyright 2021 Jan Brouwer <jan@brewsky.nl>
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

require 'rexml/document'

require File.join(File.dirname(__FILE__), 'lib_ifc', 'parse_xsd')

module BimTools
  module IfcManager
    require File.join(PLUGIN_ZIP_PATH, 'zip') unless defined? BimTools::Zip
    MAX_SIZE = 10_485_760 # 10MiB

    class SKC
      attr_reader :filepath, :name, :properties

      # Initializes a new SKC object.
      #
      # @param filename [String] The name of the SKC file.
      # @raise [StandardError] If the SKC file cannot be found.
      def initialize(filename)
        @name = ''
        @properties = {}

        # Find schema file
        plugin_filepath = File.join(PLUGIN_PATH_CLASSIFICATIONS, filename)
        filepath = if File.file?(plugin_filepath)
                     plugin_filepath
                   else
                     Sketchup.find_support_file(filename, 'Classifications')
                   end
        if filepath
          @skc_filepath = filepath
          set_skc_document_properties
        else
          message = "Unable to find SKC-file:\r\n'#{filename}'"
          raise StandardError, message
        end
      end

      # Sets the SKC document properties by reading the SKC file.
      def set_skc_document_properties
        return unless @skc_filepath

        BimTools::Zip::File.open(@skc_filepath) do |zip_file|
          if entry = zip_file.find_entry('documentProperties.xml')
            if entry.size > MAX_SIZE
              raise "Unable to load classification, SKC-file too large when extracted: #{@skc_filepath}"
            end

            begin
              document_properties = REXML::Document.new(entry.get_input_stream.read)
              document_properties.elements.each('documentProperties') do |element|
                @properties = element.elements.map { |e| [e.name.split(':').last.to_sym, e.text] }.to_h
                @name = @properties[:title] if @properties.include? :title
              end
            rescue REXML::ParseException => e
              message = "Unable to load classification, invalid SKC-file: #{@skc_filepath}"
              puts message + ", #{e.message}"
              raise StandardError, message
            end
          end
        end
      end

      # Gets the classification name from the SKC file.
      # (!) Better to read once and store in variable
      #
      # @return [String, nil] The classification name, or nil if the SKC file is not available.
      def classification_name
        return unless @skc_filepath

        BimTools::Zip::File.open(@skc_filepath) do |zip_file|
          if entry = zip_file.find_entry('documentProperties.xml')
            raise 'File too large when extracted' if entry.size > MAX_SIZE

            document_properties = REXML::Document.new(entry.get_input_stream.read)
            document_properties.elements.each('documentProperties') do |element|
              element.elements.each('dp:title') do |element|
                return element.text
              end
            end
          end
        end
      end

      # Gets the XSD schema from the SKC file.
      #
      # @return [String, nil] The XSD schema, or nil if the SKC file is not available.
      def xsd_schema
        return unless @skc_filepath

        BimTools::Zip::File.open(@skc_filepath) do |zip_file|
          xsd_file = nil

          # Find XSD file name
          if entry = zip_file.find_entry('document.xml')
            raise 'File too large when extracted' if entry.size > MAX_SIZE

              document = REXML::Document.new(entry.get_input_stream.read)
              document.elements.each('classificationDocument') do |document_element|
                document_element.elements.each('cls:Classification') do |classification_element|
                  if xsd_file = classification_element.attributes['xsdFile']
                    break
                  end
                end
                break
              end
            end

          # Read XSD file
          raise 'Unable to read classification, invalid SKC-file' unless entry = zip_file.find_entry(xsd_file)
          raise 'File too large when extracted' if entry.size > MAX_SIZE

          return entry.get_input_stream.read
        end
      end

      # Gets the filter options from the SKC file.
      #
      # @return [Array<String>] The filter options as an array of strings.
      def get_skc_options
        options = []
        return options unless @skc_filepath

        BimTools::Zip::File.open(@skc_filepath) do |zip_file|
          xsd_file_name = nil

          # Find XSD file name
          if document_file = zip_file.find_entry('document.xml')
            raise 'File too large when extracted' if document_file.size > MAX_SIZE

            classification_document = REXML::Document.new(document_file.get_input_stream.read)
            classification_document.elements.each('classificationDocument') do |element|
              element.elements.each('cls:Classification') do |element|
                if xsd_file_name = element.attributes['xsdFile']
                  break
                end
              end
              break
            end
          end

          # Read XSD filter file
          if xsd_filter_file = zip_file.find_entry(xsd_file_name + '.filter')
            raise 'File too large when extracted' if xsd_filter_file.size > MAX_SIZE

            skip = false
            xsd_filter_file.get_input_stream.read.each_line do |line|
              case line
              when "{\n"
                skip = true
              when "}\n"
                skip = false
              when "\n"
              else
                options << line.strip if !skip && !line.start_with?('//')
              end
            end
          else
            puts 'Unable to find classification filter, returning all elements as options'
            if xsd_file = zip_file.find_entry(xsd_file_name)
              raise 'File too large when extracted' if xsd_file.size > MAX_SIZE

              schema_document = REXML::Document.new(xsd_file.get_input_stream.read)
              schema_document.elements.each('xs:schema') do |schema_element|
                schema_element.elements.each('xs:element') do |element|
                  element_name = element.attributes['name']
                  options << element_name if element_name
                end
              end
            else
              puts 'Unable to find classification XSD file'
            end
          end
        end
        return options
      end
    end
  end
end
