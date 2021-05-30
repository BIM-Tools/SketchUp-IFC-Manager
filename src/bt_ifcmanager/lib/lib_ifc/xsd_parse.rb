#  xsd_parse.rb
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
require_relative 'ifc_entity.rb'

timer = Time.now

module BimTools
  module IFC2X3
    xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC2X3.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/ifcXML4.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x1.xsd")
    # xsd_path = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/IFC4x3_RC2.xsd")

    ifc = REXML::Document.new(File.new(xsd_path))
    root = ifc.root
    def self.get_base(ifc_object)
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

    def self.get_subtype(ifc_object, ifc_objects)
      base = get_base(ifc_object)
      if base
        if base == "ex:Entity" || base == "ifc:Entity"
          return BimTools::IFC2X3::IfcEntity
        elsif base.split(":")[0] == "ifc"
          subtype_name = base.split(":")[1].sub('-', '_')
          if Object.const_defined?(subtype_name)
            return BimTools::IFC2X3::const_get(subtype_name)
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

    # Get attributes
    def self.get_attributes(ifc_object)
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
      return ifc_attributes
    end

    # Find mixin module
    def self.get_mixin(ifc_name)      
      mixin_file = Pathname.new("#{PLUGIN_ROOT_PATH}/bt_ifcmanager/lib/lib_ifc/#{ifc_name}_su.rb")
      if mixin_file.exist?
        require_relative(mixin_file)
        return eval("BimTools::#{ifc_name}_su")
      end
      return nil
    end

    def self.create_ifc_class(ifc_name, ifc_object, ifc_objects)
      
      # Create class
      unless IFC2X3.const_defined?(ifc_name)
        mixin = get_mixin(ifc_name)
        subtype = get_subtype(ifc_object, ifc_objects)
        ifc_attributes = get_attributes(ifc_object)
        ifc_class = Class.new(subtype) do
          attr_accessor *ifc_attributes.map { |x| x.downcase }
          
          if mixin
            include mixin
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
        IFC2X3.const_set ifc_name, ifc_class
      end
      return BimTools::IFC2X3::const_get(ifc_name)
    end

    def self.get_ifc_objects(elements)
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

    ifc_objects = get_ifc_objects(root.elements)

    ifc_objects.each_pair do |ifc_name, ifc_object|
      unless Object.const_defined?(ifc_name)
        create_ifc_class(ifc_name, ifc_object, ifc_objects)
      end
    end
  end
end

time = Time.now - timer
puts "finished loading: #{time.to_s}"