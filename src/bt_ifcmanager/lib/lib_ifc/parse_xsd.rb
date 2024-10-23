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

# Parse XSD schema to generate IFC classes at runtime

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

    # Parses IFC schemas from an XSD file or string.
    class IfcXsdParser
      attr_reader :ifc_version, :ifc_version_compact, :ifc_module

      # IFC classes that need an additional module mixed in
      MIXIN_MODULES = %w[
        IfcAxis2Placement3D
        IfcCartesianPoint
        IfcClassificationReference
        IfcDirection
        IfcGeometricRepresentationSubContext
        IfcGroup
        IfcIndexedTriangleTextureMap
        IfcLocalPlacement
        IfcObjectDefinition
        IfcPile
        IfcPresentationLayerAssignment
        IfcProduct
        IfcRoot
        IfcRelAggregates
        IfcRelDefinesByProperties
        IfcRelDefinesByType
        IfcRelContainedInSpatialStructure
        IfcSite
        IfcSpatialStructureElement
        IfcStyledItem
        IfcTypeProduct
        IfcUnitAssignment
      ]

      ifc_order_file = File.join(File.dirname(__FILE__), 'ifc_order.yml')
      IFC_ORDER = YAML.load_file(ifc_order_file)

      # Initializes a new instance of the IfcXsdParser class for parsing IFC schemas.
      #
      # @param ifc_version [String] The version of the IFC schema to parse.
      # @param xsd_string [String] The XSD string to parse.
      # @return [IfcXsdParser] A new instance of the IfcXsdParser class.
      def initialize(ifc_version, xsd_string = nil)
        @ifc_version = ifc_version
        @ifc_version_compact = ifc_version.delete(' ').upcase
        if BimTools.const_defined?(@ifc_version_compact)
          puts "#{ifc_version} already loaded"
          @ifc_module = BimTools.const_get(@ifc_version_compact)
        else
          @ifc_module = BimTools.const_set(ifc_version_compact, Module.new)
          create_ifc_entity
          parse_from_string(xsd_string) if xsd_string
        end
      end

      # Parses an IFC schema from an XSD file.
      # This method is currently unused, but is kept for potential future use.
      #
      # @param xsd_path [String] The path to the XSD file.
      # @return [void]
      def from_file(xsd_path)
        document = REXML::Document.new(File.new(xsd_path))
        parse_document(document)
      end

      # Parses an IFC schema from an XSD string.
      #
      # @param xsd_string [String] The XSD string.
      # @return [void]
      def parse_from_string(xsd_string)
        document = REXML::Document.new(xsd_string)
        parse_document(document)
      end

      # Parses an IFC schema from a REXML::Document object.
      #
      # document - The REXML::Document object to parse.
      #
      # Returns nothing.
      def parse_document(document)
        timer = Time.now
        root = document.root

        ifc_objects = get_ifc_objects(root.elements)

        ifc_objects.each_pair do |ifc_name, ifc_object|
          create_ifc_class(ifc_name, ifc_object, ifc_objects) unless Object.const_defined?(ifc_name)
        end
        time = Time.now - timer
        puts "finished reading IFC schema: #{time}"
      end

      # Returns the base type of the given ifc_object by parsing its XSD.
      #
      # @param ifc_object [REXML::Element] The ifc_object to parse.
      # @return [String, nil] The base type of the ifc_object, or nil if not found.
      def get_base_type(ifc_object)
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

      # Determines the subtype of an IFC object based on its base type.
      # If the base type is an Entity, returns the IfcEntity class.
      # If the base type is an IFC type, returns the corresponding subtype class.
      # If the subtype class does not exist, creates it using create_ifc_class.
      # Raises an exception if the base type is not recognized.
      #
      # @param ifc_object [Object] The IFC object to determine the subtype of.
      # @param ifc_objects [Hash] A hash of all IFC objects.
      # @return [Class] The subtype class of the IFC object.
      def get_subtype(ifc_object, ifc_objects)
        base = get_base_type(ifc_object)
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

      # Sorts the attributes of the given IFC class based on the IFC_ORDER yaml file and returns explicit and inverse attributes separately.
      #
      # @param ifc_name [String] the name of the IFC entity
      # @param ifc_attributes [Array<String>] the list of attributes of the IFC entity
      # @return [Array<Array<String>, Array<String>>] the sorted list of explicit attributes and list of inverse attributes
      def sort_attributes(ifc_name, ifc_attributes)
        order = IFC_ORDER[ifc_name]
        return [ifc_attributes, []] if order.nil?

        explicit_attributes = ifc_attributes.dup
        inverse_attributes = []

        if order.key?(:inverse) && !order[:inverse].nil?
          inverse_attributes = order[:inverse]
          explicit_attributes -= inverse_attributes
        end

        if order.key?(:explicit) && !order[:explicit].nil?
          explicit_attributes.sort_by! { |e| order[:explicit].index(e) || Float::INFINITY }
        end

        [explicit_attributes, inverse_attributes]
      end

      # Gets the attributes of the given IFC object.
      #
      # @param ifc_object [REXML::Element] The IFC object.
      # @param ifc_name [String] The name of the IFC class.
      # @return [Array<String>] the list of attributes of the IFC object.
      def get_ifc_attributes(ifc_object, _ifc_name)
        ifc_attributes = Set.new
        if ifc_object
          ifc_object.elements.each('xs:complexContent/xs:extension/xs:attribute') do |attribute|
            ifc_attributes.add(attribute.attributes['name'].to_sym) if attribute.attributes['name']
          end
          ifc_object.elements.each('xs:complexContent/xs:extension/xs:sequence/xs:element') do |element|
            ifc_attributes.add(element.attributes['name'].to_sym) if element.attributes['name']
          end
        end

        # # Catch special cases where the XML schema deviates from the EXPRESS schema
        # case ifc_name
        # when 'IfcRelAggregates'
        #   ifc_attributes << :RelatingObject
        # when 'IfcRelDefinesByType'
        #   ifc_attributes << :RelatedObjects
        # when 'IfcRelDefinesByProperties'
        #   ifc_attributes << :RelatedObjects
        # when 'IfcRelContainedInSpatialStructure'
        #   ifc_attributes << :RelatingStructure
        # when 'IfcClassificationReference'
        #   ifc_attributes << :ReferencedSource
        # end

        # ifc_attributes = sort_attributes(ifc_name, ifc_attributes)

        ifc_attributes.to_a
      end

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
          puts "loaded #{ifc_name}_su"
          return BimTools.const_get(ifc_name + '_su')
        end
        nil
      end

      # Creates the IfcEntity base class if it doesn't already exist in the @ifc_module namespace.
      # The IfcEntity class includes the Step module and defines an initialize method that takes an ifc_model argument.
      # It also defines a class method called attributes that returns an empty array.
      # Returns nothing.
      def create_ifc_entity
        return if @ifc_module.const_defined?(:IfcEntity)

        ifc_class = Class.new do
          include Step
          def initialize(ifc_model, _sketchup = nil, *_args)
            @ifc_model = ifc_model
          end

          def self.attributes
            []
          end

          def self.inverse_attributes
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
      # @return The created IFC class.
      def create_ifc_class(ifc_name, ifc_object, ifc_objects)
        unless @ifc_module.const_defined?(ifc_name)
          mixin = get_mixin(ifc_name)
          subtype = get_subtype(ifc_object, ifc_objects)

          ifc_attributes = get_ifc_attributes(ifc_object, ifc_name)

          if mixin && mixin.respond_to?(:required_attributes)
            ifc_attributes.concat(mixin.required_attributes)
            ifc_attributes.uniq!
          end

          ifc_attributes ||= []
          ifc_attributes, inverse_attributes = sort_attributes(ifc_name, ifc_attributes)

          ifc_class = Class.new(subtype) do
            attr_accessor(*ifc_attributes.map { |x| x.downcase })

            # @@attribute_list = ifc_attributes
            prepend mixin if mixin
            @attr = ifc_attributes
            @inverse_attr = inverse_attributes
            def initialize(ifc_model, sketchup = nil, *args)
              @ifc_id = ifc_model.add(self) if @ifc_id.nil?
              super unless self.class.superclass == Object
            end

            def self.attributes
              # puts "#{ifc_name} attributes: #{ifc_attributes}" if ifc_name == 'IfcLocalPlacement'
              # puts "#{ifc_name} superclass.attributes: #{superclass.attributes}" if ifc_name == 'IfcLocalPlacement'
              superclass.attributes + @attr
            end

            def self.inverse_attributes
              superclass.inverse_attributes + @inverse_attr
            end

            def attributes
              self.class.attributes
            end

            def inverse_attributes
              self.class.inverse_attributes
            end
          end
          @ifc_module.const_set ifc_name, ifc_class
        end
        @ifc_module.const_get(ifc_name)
      end

      # Returns a hash of IFC objects from the given XML elements.
      # The keys of the hash are the names of the IFC objects.
      #
      # @param elements [Array<REXML::Element>] The elements to extract IFC objects from.
      #
      # @return The collection of IFC objects.
      def get_ifc_objects(elements)
        ifc_objects = {}
        elements.each('xs:complexType') do |element|
          # Skip this element if it doesn't have a name attribute.
          next unless ifc_name = element.attributes['name']

          # Skip this element if its name doesn't start with "Ifc".
          if ifc_name.start_with? 'Ifc'
            ifc_name = ifc_name.sub('-', '_')
            ifc_objects[ifc_name] = element
          end
        end
        ifc_objects
      end
    end
  end
end
