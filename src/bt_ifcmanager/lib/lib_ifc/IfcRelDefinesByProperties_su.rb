#  IfcRelDefinesByProperties_su.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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


# load types
require_relative 'set.rb'
require_relative "IfcAreaMeasure.rb"
require_relative 'IfcBoolean.rb'
require_relative "IfcCountMeasure.rb"
require_relative "IfcLabel.rb"
require_relative "IfcIdentifier.rb"
require_relative "IfcText.rb"
require_relative "IfcReal.rb"
require_relative "IfcInteger.rb"
require_relative "IfcLengthMeasure.rb"
require_relative "IfcPlaneAngleMeasure.rb"
require_relative "IfcPositiveLengthMeasure.rb"
require_relative "IfcThermalTransmittanceMeasure.rb"
require_relative "IfcVolumeMeasure.rb"
require_relative "IfcVolumetricFlowRateMeasure.rb"
require_relative "IfcPositiveRatioMeasure.rb"
require_relative "enumeration.rb"

require_relative File.join("PropertyReader.rb")

module BimTools
  module IfcRelDefinesByProperties_su
    include BimTools::IfcManager::Settings.ifc_module

    # Create quantity and propertysets from attribute dictionaries
    #
    # @param ifc_model [IfcModel] The model to which to add the properties
    # @param attr_dict [Sketchup::AttributeDictionary] The attribute dictionary to extract properties from
    #
    def initialize(ifc_model, attr_dict=nil)
      @ownerhistory = ifc_model.owner_history
      @relatedobjects = IfcManager::Ifc_Set.new()
      if attr_dict
        if attr_dict.name == "BaseQuantities" # export as elementquantities
          quantities = IfcManager::Ifc_Set.new()          
          attr_dict.attribute_dictionaries.each do | qty_dict |
            if qty_dict['value']
              case qty_dict.name
              when "Area", "GrossArea"
                prop = IfcQuantityArea.new( ifc_model, attr_dict )
                prop.name = BimTools::IfcManager::IfcIdentifier.new( qty_dict.name )
                prop.areavalue = BimTools::IfcManager::IfcAreaMeasure.new( qty_dict['value'] )
                qty.quantities.add( prop )
              when "Volume"
                prop = IfcQuantityVolume.new( ifc_model, attr_dict )
                prop.name = BimTools::IfcManager::IfcIdentifier.new( qty_dict.name )
                prop.volumevalue = BimTools::IfcManager::IfcVolumeMeasure.new( qty_dict['value'] )
                qty.quantities.add( prop )
              when "Width", "Height", "Depth", "Perimeter"
                prop = IfcQuantityLength.new( ifc_model, attr_dict )
                prop.name = BimTools::IfcManager::IfcIdentifier.new( qty_dict.name )
                prop.lengthvalue = BimTools::IfcManager::IfcLengthMeasure.new( qty_dict['value'] )
                qty.quantities.add( prop )
              #else
              end
            end
          end

          # Create ElementQuantity if there are any quantities to export
          unless quantities.empty?
            @relatingpropertydefinition = IfcElementQuantity.new( ifc_model, attr_dict )
            @relatingpropertydefinition.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name ) unless attr_dict.name.nil?
            @relatingpropertydefinition.quantities = quantities
          end
          
        else # export as propertyset
          properties = IfcManager::Ifc_Set.new()

          # removed check for attr_dict length due to the fact the sketchup classifier always adds is_hidden property
          if attr_dict.attribute_dictionaries# && attr_dict.length == 0
            attr_dict.attribute_dictionaries.each do | prop_dict |

              # # When properties are stored WITHOUT an IFC type nesting level
              # #   as they are when imported from an IFC file then val_dict == prop_dict
              # if !prop_dict['value'] && prop_dict.attribute_dictionaries
              #   val_dict = false
              #   prop_dict.attribute_dictionaries.each do |dict|
              #     if dict.name != "instanceAttributes"
              #       val_dict = dict
              #       break
              #     end
              #   end
              #   value_type = val_dict.name
              # else
              #   val_dict = prop_dict
              #   value_type = false
              # end

              # Don't export empty properties
              property_reader = BimTools::PropertyReader.new(prop_dict)
              if dict_value = property_reader.value
                value_type = property_reader.value_type
                attribute_type = property_reader.attribute_type

                # attribute_type = val_dict['attribute_type']
                # dict_value = val_dict['value']
                if attribute_type == "enumeration"
                  prop = IfcPropertyEnumeratedValue.new( ifc_model )
                  value = BimTools::IfcManager::IfcLabel.new(dict_value)
                  value.long = true # adding long = true returns a full object string, necessary for propertyset
                  prop.enumerationvalues = IfcManager::Ifc_List.new([value])
                else
                  prop = IfcPropertySingleValue.new( ifc_model )
                  entity_type = false
                  if value_type
                    begin
                      entity_type = BimTools::IfcManager.const_get(value_type)
                      prop.nominalvalue = entity_type.new(dict_value)
                    rescue => e
                      puts "Error creating IFC property type: #{value_type}, #{ e.to_s}"
                    end
                  end
                  unless entity_type
                    case attribute_type
                    when "boolean"
                      prop.nominalvalue = BimTools::IfcManager::IfcBoolean.new(dict_value)
                    when "double"
                      prop.nominalvalue = BimTools::IfcManager::IfcReal.new(dict_value)
                    when "long"
                      prop.nominalvalue = BimTools::IfcManager::IfcInteger.new(dict_value)
                    else # "string" and others?
                      prop.nominalvalue = BimTools::IfcManager::IfcLabel.new(dict_value)
                    end
                  end
                  prop.nominalvalue.long = true
                end
                prop.name = BimTools::IfcManager::IfcIdentifier.new( prop_dict.name )
                properties.add( prop )
              end
            end
          else
            attr_dict.each do | key, value |
              if value
                prop = IfcPropertySingleValue.new( ifc_model, attr_dict )
                prop.name = BimTools::IfcManager::IfcIdentifier.new( key )
                prop.nominalvalue = BimTools::IfcManager::IfcLabel.new( value ) # (!) not always IfcLabel
                prop.nominalvalue.long = true # adding long = true returns a full object string
                properties.add( prop )
              end
            end
          end
          
          # Create PropertySet if there are any properties to export
          unless properties.empty?
            @relatingpropertydefinition = IfcPropertySet.new( ifc_model )
            @relatingpropertydefinition.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name )
            @relatingpropertydefinition.hasproperties = properties
          end
        end
      end
    end
  end
end