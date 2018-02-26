#  dynamic_attributes.rb
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

require_relative File.join('IfcLengthMeasure.rb')
require_relative File.join('IfcLabel.rb')
require_relative File.join('IfcReal.rb')

# method that collects all dynamic component attributes in the given objects and creates IfcPropertySets and Quantities
 
module BimTools
 module DynamicAttributes
  def self.get_dynamic_attributes( ifc_model, ifc_object )
    
    definition = ifc_object.su_object.definition
    pset_hash = Hash.new
    qty_hash = Hash.new
    
    if definition.attribute_dictionary "dynamic_attributes"
      attr_dict = definition.attribute_dictionary "dynamic_attributes"
      attr_dict.each_pair { | key, value |
      
        # collect "main" fields --> keys NOT beginning with "_"
        unless key.start_with?('_')
          # get all corresponding data fields
          label = attr_dict["_#{key}_formlabel"]
          units = attr_dict["_#{key}_units"]
          name = attr_dict["_#{key}_label"]
          #value = value
          
          name_parts = name.split("_")
          pset_name = "#{name_parts[0]}_#{name_parts[1]}"
          prop_name = name_parts.last
          
          case name_parts[0]
          when "Pset", "pset"
            
            # create new PropertySet with name pset_name
            unless pset_hash[pset_name]
              reldef = BimTools::IFC2X3::IfcRelDefinesByProperties.new( ifc_model, nil )
              reldef.relatedobjects.add( ifc_object )
              pset = BimTools::IFC2X3::IfcPropertySet.new( ifc_model, attr_dict )
              pset.name = BimTools::IfcManager::IfcLabel.new( pset_name )
              pset.hasproperties = IfcManager::Ifc_Set.new()
              reldef.relatingpropertydefinition = pset
              pset_hash[pset_name] = pset
            end
            
            # create Property with name prop_name
            property = BimTools::IFC2X3::IfcPropertySingleValue.new( ifc_model )
            property.name = BimTools::IfcManager::IfcLabel.new( prop_name )
            property.nominalvalue = get_dynamic_attribute_value( attr_dict, key )
            property.nominalvalue.long = true
            pset_hash[pset_name].hasproperties.add( property )
          when "Qty", "BaseQuantities"
            unless qty_hash[key]
              # create new QuantitySet with name key
            end
          else
            
            # create new PropertySet with name "SU_DynamicAttributes"
            unless pset_hash["SU_DynamicAttributes"]
              reldef = BimTools::IFC2X3::IfcRelDefinesByProperties.new( ifc_model, nil )
              reldef.relatedobjects.add( ifc_object )
              pset = BimTools::IFC2X3::IfcPropertySet.new( ifc_model, attr_dict )
              pset.name = BimTools::IfcManager::IfcLabel.new( "SU_DynamicAttributes" )
              pset.hasproperties = IfcManager::Ifc_Set.new()
              reldef.relatingpropertydefinition = pset
              pset_hash["SU_DynamicAttributes"] = pset
            end
            
            # create Property with name prop_name
            property = BimTools::IFC2X3::IfcPropertySingleValue.new( ifc_model )
            property.name = BimTools::IfcManager::IfcLabel.new( prop_name )
            property.nominalvalue = get_dynamic_attribute_value( attr_dict, key )
            property.nominalvalue.long = true
            pset_hash["SU_DynamicAttributes"].hasproperties.add( property )
          end
        end
      }
    end
  end # def get_dynamic_attributes
  
  def self.get_dynamic_attribute_value( dict, key )
    value = dict[key]
    
    # exception: Default fields lenx, leny and lenz are always "DEFAULT" meaning Length
    if ["lenx","leny","lenz"].include? key
      return BimTools::IfcManager::IfcLengthMeasure.new( value.to_f.to_mm ) # (!)(?) always mm?
    end
    
    # get unit, use "formulaunits" if possible, if not use "units"
    unless units = dict["_#{key}_formulaunits"]
      units = dict["_#{key}_units"]
    end
    
    case units
    when "CENTIMETERS", "INCHES"
      return BimTools::IfcManager::IfcLengthMeasure.new( value.to_f.to_mm ) # (!)(?) always mm?
    when "STRING"
      return BimTools::IfcManager::IfcLabel.new( value )
    when "FLOAT"
      return BimTools::IfcManager::IfcReal.new( value.to_f )
    else # (?) when "DEFAULT"
      if value.is_a? Length
        return BimTools::IfcManager::IfcLengthMeasure.new( value.to_mm ) # (!)(?) always mm?
      elsif value.is_a? String
        return BimTools::IfcManager::IfcLabel.new( value )
      elsif value.is_a? Float
        return BimTools::IfcManager::IfcReal.new( value.to_f )
      end
    end
  end # def get_dynamic_attribute_value
 end # module DynamicAttributes
end # module BimTools
