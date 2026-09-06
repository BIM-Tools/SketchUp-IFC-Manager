# frozen_string_literal: true

#  xsd_classification_reader.rb
#
#  Copyright 2026 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcManager
    # Reads a standalone (non-SKC-wrapped) .xsd classification schema, as can be
    # loaded directly into a SketchUp model through
    # Window > Model Info > Classifications > Import ('*.skc' or '*.xsd').
    #
    # Exposes the same duck-typed interface as SKC (#name, #get_options) so
    # callers (Settings, PropertiesWindow) can treat both file types the same
    # way regardless of which one backs a given loaded classification.
    class XsdClassification
      attr_reader :filepath, :name

      # @param filename [String] The XSD file name.
      # @raise [StandardError] If the XSD file cannot be found.
      def initialize(filename)
        plugin_filepath = File.join(PLUGIN_PATH_CLASSIFICATIONS, filename)
        filepath = if File.file?(plugin_filepath)
                     plugin_filepath
                   else
                     Sketchup.find_support_file(filename, 'Classifications')
                   end

        unless filepath
          message = "Unable to find XSD classification file:\r\n'#{filename}'"
          raise StandardError, message
        end

        @filepath = filepath
        @name = read_name
      end

      # Gets the filter options from the XSD file.
      #
      # Mirrors SKC#get_skc_options, but a lone .xsd has no embedded '.filter'
      # sidecar (that's an SKC/zip-only concept), so every top-level
      # xs:element name found in the schema is offered as an option.
      #
      # @return [Array<String>] The filter options as an array of strings.
      def get_options
        options = []
        schema_document = REXML::Document.new(File.read(@filepath))
        schema_document.elements.each('xs:schema/xs:element') do |element|
          element_name = element.attributes['name']
          options << element_name if element_name
        end
        options
      rescue StandardError => e
        puts "Unable to read XSD classification options from '#{@filepath}': #{e.message}"
        []
      end
      alias get_skc_options get_options

      private

      # A bare .xsd carries no documentProperties/title metadata (unlike
      # .skc), so fall back to the file name as the classification's display
      # name.
      def read_name
        File.basename(@filepath, '.xsd')
      end
    end
  end
end
