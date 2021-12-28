#  add_common_psets.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
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

require 'rexml/document'
include REXML

module BimTools::IfcManager

  # Finds and adds common propertyset for definition IFC type
  # @param [Sketchup::ComponentDefinition] definition
  # @param [String] ent_type_name
  def add_common_psets(definition, ent_type_name)
    ifc_dict = definition.attribute_dictionary(BimTools::IfcManager::Settings.ifc_version)
    if ifc_dict
      entity_type = BimTools::IfcManager::Settings.ifc_module.const_get(ent_type_name)
      prefix = BimTools::IfcManager::Settings.ifc_module
      entity_type.ancestors.each do |ancestor|
        name = ancestor.name
        split_name = ancestor.name.split('::Ifc')
        if split_name.length == 2
          basename = split_name.last
          if !basename.end_with?("_su")
            filename = File.join(PLUGIN_PATH_LIB, "lib_ifc", "psd", "Pset_#{basename}Common.xml" )
            xml_file = File.file?(filename)
            if xml_file
              xmlfile = File.new(filename)
              xmldoc = Document.new(xmlfile)
              xmldoc.elements.each("PropertySetDef") do |e|
                propertyset_name =  e.elements().to_a("Name").first.text
                pset_dict = ifc_dict.attribute_dictionary(propertyset_name, true)
                e.elements.each("PropertyDefs/PropertyDef") do |e|
                  property_name = e.elements().to_a("Name").first.text
                  property_type = e.elements().to_a("PropertyType").first.elements().to_a().first.name

                  # Only add TypePropertySingleValue and TypePropertyEnumeratedValue
                  # Possible property value types
                  # - TypePropertySingleValue
                  # - TypePropertyEnumeratedValue : "choice"?
                  # - TypePropertyBoundedValue
                  # - TypePropertyReferenceValue
                  if property_type == "TypePropertySingleValue"
                    
                    # Possible sketchup value types
                    # - boolean
                    # - choice
                    # - long # integer?
                    # - double
                    # - string
                    value_type = e.elements().to_a("PropertyType/TypePropertySingleValue/DataType").first["type"]
                    if value_type
                      if value_type == "IfcBoolean"
                        attribute_type = "boolean"
                        # value = false
                      elsif value_type == "IfcInteger"
                        attribute_type = "long"
                        # value = 0
                      elsif value_type.include?("Measure")
                        attribute_type = "double"
                        # value = 0.0
                      else
                        attribute_type = "string"
                        # value = ""
                      end
                      property_dict = pset_dict.attribute_dictionary(property_name, true)
                      pset_dict.set_attribute property_name, "is_hidden", false
                      value_dict = property_dict.attribute_dictionary(value_type, true)
                      property_dict.set_attribute value_type, "attribute_type", attribute_type
                      property_dict.set_attribute value_type, "is_hidden", false
                      property_dict.set_attribute value_type, "value", nil # value
                    else
                      puts "DataType not found"
                    end
                  elsif property_type == "TypePropertyEnumeratedValue"
                    value_type = e.elements().to_a("PropertyType/TypePropertyEnumeratedValue/EnumList").first["name"]
                    options = e.get_elements('PropertyType/TypePropertyEnumeratedValue/EnumList/EnumItem').map { |e| e.text() }
                    property_dict = pset_dict.attribute_dictionary(property_name, true)
                    pset_dict.set_attribute property_name, "is_hidden", false
                    value_dict = property_dict.attribute_dictionary(value_type, true)
                    property_dict.set_attribute value_type, "attribute_type", "enumeration"
                    property_dict.set_attribute value_type, "is_hidden", false
                    property_dict.set_attribute value_type, "options", options
                    property_dict.set_attribute value_type, "value", options.last # value
                  end
                end
              end
            end
          end
        end
      end
      return false
    end
  end
end