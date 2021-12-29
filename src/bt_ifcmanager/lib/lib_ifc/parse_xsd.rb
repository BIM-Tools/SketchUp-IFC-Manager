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

require_relative(File.join('.', 'step.rb'))
# require_relative 'ifc_entity.rb'


module BimTools
  module IfcManager
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC2X3.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/ifcXML4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x1.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x3_RC2.xsd")
    class IfcXmlParser

      ifc_order_file = File.join(File.dirname(__FILE__), 'ifc_order.yml')
      IFC_ORDER = YAML::load_file(ifc_order_file)

      def initialize(ifc_version)
        @ifc_version = ifc_version
        ifc_version_compact = ifc_version.delete(' ').upcase
        @ifc_module = BimTools.const_set(ifc_version_compact, Module.new)
        BimTools::IfcManager::Settings.ifc_version = ifc_version
        BimTools::IfcManager::Settings.ifc_version_compact = ifc_version_compact
        BimTools::IfcManager::Settings.ifc_module = @ifc_module
        create_ifcentity()
      end
      
      def from_file(xsd_path)
        document = REXML::Document.new(File.new(xsd_path))
        self.parse(document)
      end

      def from_string(xsd_string)
        document = REXML::Document.new(xsd_string)
        self.parse(document)
      end

      def parse(document)
        timer = Time.now
        root = document.root

        ifc_objects = get_ifc_objects(root.elements)

        ifc_objects.each_pair do |ifc_name, ifc_object|
          unless Object.const_defined?(ifc_name)
            create_ifc_class(ifc_name, ifc_object, ifc_objects)
          end
        end
        time = Time.now - timer
        puts "finished loading: #{time.to_s}"
      end
      
      def get_base(ifc_object)
        if ifc_object
          ifc_object.elements.each("xs:complexContent/xs:extension") do |extension|
            if extension.attributes["base"]
              return extension.attributes["base"]
            end
          end
          ifc_object.elements.each("xs:complexContent/xs:restriction") do |restriction|
            if restriction.attributes["base"]
              return restriction.attributes["base"]
            end
          end
        end
        return nil
      end

      def get_subtype(ifc_object, ifc_objects)
        base = get_base(ifc_object)
        if base
          if base == "ex:Entity" || base == "ifc:Entity"
            return @ifc_module.const_get("IfcEntity")
          elsif base.split(":")[0] == "ifc"
            subtype_name = base.split(":")[1].sub('-', '_')
            if Object.const_defined?(subtype_name)
              return @ifc_module.const_get(subtype_name)
            else
              return create_ifc_class(subtype_name, ifc_objects[subtype_name], ifc_objects)
            end
          else
            raise ifc_name
          end
        else
          return Object
        end
      end

      def sort_attributes(ifc_name, ifc_attributes)
        if IFC_ORDER.key?(ifc_name)
          order = IFC_ORDER[ifc_name]
          if order.key?(:inverse)
            ifc_attributes = ifc_attributes - order[:inverse]
          end
          if order.key?(:explicit)
            return ifc_attributes.sort_by { |e| order[:explicit].index(e) || Float::INFINITY }
          end
        end
        return ifc_attributes
      end

      # Get attributes
      def get_attributes(ifc_object, ifc_name)
        ifc_attributes = []
        if ifc_object
          ifc_object.elements.each("xs:complexContent/xs:extension") do |extension|
            extension.elements.each("xs:attribute") do |attribute|
              if attribute.attributes["name"]
                ifc_attributes << attribute.attributes["name"].to_sym
              end
            end
            extension.elements.each("xs:sequence/xs:element") do |attribute|
              if attribute.attributes["name"]
                ifc_attributes << attribute.attributes["name"].to_sym
              end
            end
          end
        end




        # file = File.join(File.dirname(__FILE__), 'ifc_order.yml')
        # d = YAML::load_file(file)
        # unless ifc_attributes.empty?
        #   d[ifc_name] = {:explicit => ifc_attributes}
        # end
        # File.open(file, 'w') {|f| f.write d.to_yaml } #Store




        return sort_attributes(ifc_name, ifc_attributes)
      end

      # Find mixin module
      def get_mixin(ifc_name)      
        mixin_file = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/#{ifc_name}_su.rb")
        if mixin_file.exist?
          require_relative(mixin_file)
          return BimTools.const_get(ifc_name + '_su')
        end
        return nil
      end

      # Create IfcEntity base class
      def create_ifcentity()
        unless @ifc_module.const_defined?(:IfcEntity)
          ifc_class = Class.new() do
            include Step
            def initialize( ifc_model, sketchup=nil, *args )
              @ifc_model = ifc_model
            end
            def self.attributes()
              []
            end
          end
          @ifc_module.const_set( :IfcEntity, ifc_class )
        end
      end

      def create_ifc_class(ifc_name, ifc_object, ifc_objects)        
        unless @ifc_module.const_defined?(ifc_name)
          mixin = get_mixin(ifc_name)
          subtype = get_subtype(ifc_object, ifc_objects)
          ifc_attributes = get_attributes(ifc_object, ifc_name)
          ifc_class = Class.new(subtype) do
            attr_accessor *ifc_attributes.map { |x| x.downcase }
            # @@attribute_list = ifc_attributes
            if mixin
              prepend mixin
            end
            @attr = ifc_attributes
            def initialize( ifc_model=nil, sketchup=nil, *args )
              @ifc_id = ifc_model.add( self ) if @ifc_id.nil?
              unless self.class.superclass == Object
                super
              end
            end
            def self.attributes()
              self.superclass.attributes() + @attr
            end
            def attributes()
              self.class.attributes()
            end
          end
          @ifc_module.const_set ifc_name, ifc_class
        end        
        return @ifc_module.const_get(ifc_name)
      end

      def get_ifc_objects(elements)
        h = {}
        elements.each("xs:complexType") do |element|
          if ifc_name = element.attributes["name"]
            if ifc_name.start_with? "Ifc"
              ifc_name = ifc_name.sub('-', '_')
              h[ifc_name] = element
            end
          end
        end
        return h
      end
    end
  end
end
