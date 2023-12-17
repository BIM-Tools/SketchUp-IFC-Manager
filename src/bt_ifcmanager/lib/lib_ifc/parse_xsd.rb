# frozen_string_literal: true

#  parse_xsd.rb
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

# Parse IFX XSD schema to generate classes at runtime

require 'pathname'
require 'rexml/document'
require 'yaml'

require_relative File.join('.', 'step')

module BimTools
  module IfcManager
    # The IfcManager module provides functionality for parsing and working with IFC files.

    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC2X3.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/ifcXML4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x1.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x3_RC2.xsd")
    class IfcXmlParser
      ifc_order_file = File.join(File.dirname(__FILE__), 'ifc_order.yml')
      IFC_ORDER = YAML.load_file(ifc_order_file)

      # Initializes a new instance of the ParseXSD class.
      #
      # Parameters:
      # - ifc_version: The IFC version to be used.
      # - xsd_string: Optional. The XSD string to be parsed.
      #
      # Returns:
      # - A new instance of the ParseXSD class.
      def initialize(ifc_version, xsd_string = nil)
        @ifc_version = ifc_version
        ifc_version_compact = ifc_version.delete(' ').upcase
        if BimTools.const_defined?(ifc_version_compact)
          puts "#{ifc_version} already loaded"
          @ifc_module = BimTools.const_get(ifc_version_compact)
        else
          @ifc_module = BimTools.const_set(ifc_version_compact, Module.new)
          create_ifcentity
          from_string(xsd_string) if xsd_string
        end
        Settings.ifc_version = ifc_version
        Settings.ifc_version_compact = ifc_version_compact
        Settings.ifc_module = @ifc_module
      end

      # Parses an XSD file and returns the parsed document.
      #
      # Parameters:
      # - xsd_path: The path to the XSD file.
      #
      # Returns:
      # The parsed document.
      def from_file(xsd_path)
        document = REXML::Document.new(File.new(xsd_path))
        parse(document)
      end

      # Parses an XSD string and returns the parsed document.
      #
      # Parameters:
      # - xsd_string: The XSD string to parse.
      #
      # Returns:
      # The parsed document.
      def from_string(xsd_string)
        document = REXML::Document.new(xsd_string)
        parse(document)
      end

      # Parses the given IFC XSD document.
      #
      # Parameters:
      # - document: The document to parse.
      #
      # Returns:
      # - None.
      def parse(document)
        timer = Time.now
        root = document.root

        ifc_objects = get_ifc_objects(root.elements)

        ifc_objects.each_pair do |ifc_name, ifc_object|
          create_ifc_class(ifc_name, ifc_object, ifc_objects) unless Object.const_defined?(ifc_name)
        end
        time = Time.now - timer
        puts "finished loading: #{time}"
      end

      # Gets the base class of the given IFC object.
      #
      # Parameters:
      # - ifc_object: The IFC object.
      #
      # Returns:
      # - The base class of the IFC object.
      def get_base(ifc_object)
        if ifc_object
          ifc_object.elements.each('xs:complexContent/xs:extension') do |extension|
            return extension.attributes['base'] if extension.attributes['base']
          end
          ifc_object.elements.each('xs:complexContent/xs:restriction') do |restriction|
            return restriction.attributes['base'] if restriction.attributes['base']
          end
        end
        nil
      end

      # Gets the subtype of the given IFC object.
      #
      # Parameters:
      # - ifc_object: The IFC object.
      # - ifc_objects: The collection of IFC objects.
      #
      # Returns:
      # - The subtype of the IFC object.
      def get_subtype(ifc_object, ifc_objects)
        base = get_base(ifc_object)
        if base
          if ['ex:Entity', 'ifc:Entity'].include?(base)
            @ifc_module.const_get('IfcEntity')
          elsif base.split(':')[0] == 'ifc'
            subtype_name = base.split(':')[1].sub('-', '_')
            if Object.const_defined?(subtype_name)
              @ifc_module.const_get(subtype_name)
            else
              create_ifc_class(subtype_name, ifc_objects[subtype_name], ifc_objects)
            end
          else
            raise ifc_name
          end
        else
          Object
        end
      end

      # Sorts the attributes of the given IFC class based on the IFC_ORDER yaml file.
      #
      # Parameters:
      # - ifc_name: The name of the IFC class.
      # - ifc_attributes: The attributes of the IFC class.
      #
      # Returns:
      # - The sorted attributes of the IFC class.
      def sort_attributes(ifc_name, ifc_attributes)
        if IFC_ORDER.key?(ifc_name)
          order = IFC_ORDER[ifc_name]
          ifc_attributes -= order[:inverse] if order.key?(:inverse)
          return ifc_attributes.sort_by { |e| order[:explicit].index(e) || Float::INFINITY } if order.key?(:explicit)
        end
        ifc_attributes
      end

      # Gets the attributes of the given IFC object.
      #
      # Parameters:
      # - ifc_object: The IFC object.
      # - ifc_name: The name of the IFC class.
      #
      # Returns:
      # - The attributes of the IFC object.
      def get_attributes(ifc_object, ifc_name)
        ifc_attributes = []
        if ifc_object
          ifc_object.elements.each('xs:complexContent/xs:extension') do |extension|
            extension.elements.each('xs:attribute') do |attribute|
              ifc_attributes << attribute.attributes['name'].to_sym if attribute.attributes['name']
            end
            extension.elements.each('xs:sequence/xs:element') do |attribute|
              ifc_attributes << attribute.attributes['name'].to_sym if attribute.attributes['name']
            end
          end
        end
        sort_attributes(ifc_name, ifc_attributes)
      end

      # IFC classes that need an additional module mixed in
      MIXIN_MODULES = %w[
        IfcAxis2Placement3D
        IfcCartesianPoint
        IfcDirection
        IfcGroup
        IfcIndexedTriangleTextureMap
        IfcLocalPlacement
        IfcObjectDefinition
        IfcPresentationLayerAssignment
        IfcProduct
        IfcRoot
        IfcSite
        IfcSpatialStructureElement
        IfcStyledItem
        IfcTypeProduct
        IfcUnitAssignment
      ]

      # Gets the mixin module for the given IFC class.
      #
      # Parameters:
      # - ifc_name: The name of the IFC class.
      #
      # Returns:
      # - The mixin module for the IFC class.
      def get_mixin(ifc_name)
        return unless MIXIN_MODULES.include?(ifc_name)

        mixin_file = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/#{ifc_name}_su.rb")
        if mixin_file.exist?
          require_relative(mixin_file)
          return BimTools.const_get(ifc_name + '_su')
        end
        nil
      end

      # Creates the IfcEntity base class.
      #
      # Parameters:
      # - None.
      #
      # Returns:
      # - None.
      def create_ifcentity
        return if @ifc_module.const_defined?(:IfcEntity)

        ifc_class = Class.new do
          include Step
          def initialize(ifc_model, _sketchup = nil, *_args)
            @ifc_model = ifc_model
          end

          def self.attributes
            []
          end
        end
        @ifc_module.const_set(:IfcEntity, ifc_class)
      end

      # Creates the IFC class for the given IFC name.
      #
      # Parameters:
      # - ifc_name: The name of the IFC class.
      # - ifc_object: The IFC object.
      # - ifc_objects: The collection of IFC objects.
      #
      # Returns:
      # - The created IFC class.
      def create_ifc_class(ifc_name, ifc_object, ifc_objects)
        unless @ifc_module.const_defined?(ifc_name)
          mixin = get_mixin(ifc_name)
          subtype = get_subtype(ifc_object, ifc_objects)
          ifc_attributes = get_attributes(ifc_object, ifc_name)
          ifc_class = Class.new(subtype) do
            attr_accessor(*ifc_attributes.map { |x| x.downcase })

            # @@attribute_list = ifc_attributes
            prepend mixin if mixin
            @attr = ifc_attributes
            def initialize(ifc_model, sketchup = nil, *args)
              @ifc_id = ifc_model.add(self) if @ifc_id.nil?
              super unless self.class.superclass == Object
            end

            def self.attributes
              superclass.attributes + @attr
            end

            def attributes
              self.class.attributes
            end
          end
          @ifc_module.const_set ifc_name, ifc_class
        end
        @ifc_module.const_get(ifc_name)
      end

      # Gets the IFC objects from the given elements.
      #
      # Parameters:
      # - elements: The elements to extract IFC objects from.
      #
      # Returns:
      # - The collection of IFC objects.
      def get_ifc_objects(elements)
        h = {}
        elements.each('xs:complexType') do |element|
          next unless ifc_name = element.attributes['name']

          if ifc_name.start_with? 'Ifc'
            ifc_name = ifc_name.sub('-', '_')
            h[ifc_name] = element
          end
        end
        h
      end
    end
  end
end
