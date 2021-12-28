#  IfcGroup_su.rb
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

require_relative 'set.rb'

module BimTools
  module IfcGroup_su
    include BimTools::IfcManager::Settings.ifc_module

    # @parameter ifc_model [IfcManager::IfcModel]
    # @parameter sketchup [Sketchup::ComponentDefinition]
    def initialize(ifc_model, sketchup=nil)
      super

      @rel = IfcRelAssignsToGroup.new( ifc_model )
      @rel.relatinggroup = self
      @rel.relatedobjects = IfcManager::Ifc_Set.new()

      #(!) Functionalty and code is similar to IfcProduct, should be merged
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance)
        
        # get properties from su object and add them to ifc object
        definition = sketchup.definition
        
        #(?) set name, here? is this a duplicate?
        @name = BimTools::IfcManager::IfcLabel.new(definition.name)

        # also set "tag" to component instance name?
        # tag definition: The tag (or label) identifier at the particular instance of a product, e.g. the serial number, or the position number. It is the identifier at the occurrence level.
        
        if definition.attribute_dictionaries
          if definition.attribute_dictionaries["IFC 2x3"]
            if props_ifc = definition.attribute_dictionaries["IFC 2x3"].attribute_dictionaries
              props_ifc.each do |prop_dict|
                prop = prop_dict.name
                prop_sym = prop.to_sym
                if properties.include? prop_sym

                  property_reader = BimTools::PropertyReader.new(prop_dict)
                  dict_value = property_reader.value
                  value_type = property_reader.value_type
                  attribute_type = property_reader.attribute_type
                  
                  if attribute_type == "choice"
                    # Skip this attribute, this is not a value but a reference
                  elsif attribute_type == "enumeration"
                    send("#{prop.downcase}=", BimTools::IfcManager::Enumeration.new(dict_value))
                  else
                    entity_type = false
                    if value_type
                      begin
                        # require_relative ent_type_name
                        entity_type = eval("BimTools::IfcManager::#{value_type}")
                        value_entity = entity_type.new(dict_value)
                      rescue => e
                        puts "Error creating IFC type: #{ e.to_s}"
                      end
                    end
                    unless entity_type
                      
                      case attribute_type
                      when "boolean"
                        value_entity = BimTools::IfcManager::IfcBoolean.new(dict_value)
                      when "double"
                        value_entity = BimTools::IfcManager::IfcReal.new(dict_value)
                      when "long"
                        value_entity = BimTools::IfcManager::IfcInteger.new(dict_value)
                      else # "string" and others?
                        value_entity = BimTools::IfcManager::IfcLabel.new(dict_value)
                      end
                    end
                    send("#{prop.downcase}=", value_entity)
                  end
                else
                  if prop_dict.attribute_dictionaries && prop_dict.name != "instanceAttributes"
                    reldef = BimTools::IFC2X3::IfcRelDefinesByProperties.new( ifc_model, prop_dict )
                    reldef.relatedobjects.add( self )
                  end
                end
              end
            end
          end
        end
      end
    end
    
    def add(entity)
      @rel.relatedobjects.add(entity)
    end
    
    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split("::").last)
      super
    end
  end
end
