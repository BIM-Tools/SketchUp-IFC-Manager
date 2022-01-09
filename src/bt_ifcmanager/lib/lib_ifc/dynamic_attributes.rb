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

require_relative 'set'
require_relative 'IfcLengthMeasure'
require_relative 'IfcLabel'
require_relative 'IfcReal'

# method that collects all dynamic component attributes in the given objects and creates IfcPropertySets and Quantities

module BimTools
  module DynamicAttributes
    include BimTools::IfcManager::Settings.ifc_module

    def self.get_dynamic_attributes(ifc_model, ifc_object)
      @ifc_model = ifc_model
      instance = ifc_object.su_object
      definition = instance.definition
      pset_hash = {}
      qty_hash = {}

      if definition.attribute_dictionary 'dynamic_attributes'
        attr_dict = definition.attribute_dictionary 'dynamic_attributes'
        attr_dict.each_pair do |key, _value|
          # collect "main" fields --> keys NOT beginning with "_"
          next if key.start_with?('_')

          # get all corresponding data fields
          label = attr_dict["_#{key}_formlabel"]
          units = attr_dict["_#{key}_units"]
          name = attr_dict["_#{key}_label"]
          units = attr_dict["_#{key}_formulaunits"]

          # only write propertyset when label is set
          next unless name

          name_parts = name.split('_')
          pset_name = "#{name_parts[0]}_#{name_parts[1]}"
          prop_name = name_parts.last

          case name_parts[0]
          when 'Pset', 'pset', 'CPset', 'cpset'

            # create new PropertySet with name pset_name
            unless pset_hash[pset_name]
              reldef = IfcRelDefinesByProperties.new(ifc_model)
              reldef.relatedobjects.add(ifc_object)
              pset = IfcPropertySet.new(ifc_model, attr_dict)
              pset.name = BimTools::IfcManager::IfcLabel.new(ifc_model, pset_name)
              pset.hasproperties = IfcManager::Ifc_Set.new
              reldef.relatingpropertydefinition = pset
              pset_hash[pset_name] = pset
            end

            # create Property with name prop_name
            property = IfcPropertySingleValue.new(ifc_model)
            property.name = BimTools::IfcManager::IfcLabel.new(ifc_model, prop_name)
            property.nominalvalue = get_dynamic_attribute_value(instance, key)
            property.nominalvalue.long = true if property.nominalvalue
            pset_hash[pset_name].hasproperties.add(property)
          when 'Qty', 'BaseQuantities'
            unless qty_hash[key]
              # create new QuantitySet with name key
            end
          else

            # check if field is visible
            if %w[VIEW LIST TEXTBOX].include? attr_dict["_#{key}_access"]

              # create new PropertySet with name "SU_DynamicAttributes"
              unless pset_hash['SU_DynamicAttributes']
                reldef = IfcRelDefinesByProperties.new(ifc_model)
                reldef.relatedobjects.add(ifc_object)
                pset = IfcPropertySet.new(ifc_model, attr_dict)
                pset.name = BimTools::IfcManager::IfcLabel.new(ifc_model, 'SU_DynamicAttributes')
                pset.hasproperties = IfcManager::Ifc_Set.new
                reldef.relatingpropertydefinition = pset
                pset_hash['SU_DynamicAttributes'] = pset
              end

              # create Property with name prop_name
              property = IfcPropertySingleValue.new(ifc_model)
              property.name = BimTools::IfcManager::IfcLabel.new(ifc_model, prop_name)
              property.nominalvalue = get_dynamic_attribute_value(instance, key)
              property.nominalvalue.long = true if property.nominalvalue
              pset_hash['SU_DynamicAttributes'].hasproperties.add(property)
            end
          end
        end
      end
    end

    def self.get_dynamic_attribute_value(instance, key)
      dict = instance.definition.attribute_dictionary 'dynamic_attributes'
      instance_dict = instance.attribute_dictionary 'dynamic_attributes'

      # if instance value is empty, then use definition value
      value = if instance_dict && instance_dict[key]
                instance_dict[key]
              elsif dict && dict[key]
                dict[key]
              end

      # exception: Default fields lenx, leny and lenz are always "DEFAULT" meaning Length
      return BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, value) if %w[lenx leny lenz].include? key

      # get unit, use "formulaunits" if possible, if not use "units"
      unless units = dict["_#{key}_formulaunits"]
        units = dict["_#{key}_units"]
      end

      case units
      when 'CENTIMETERS', 'INCHES'
        BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, value)
      when 'STRING'
        BimTools::IfcManager::IfcLabel.new(@ifc_model, value)
      when 'FLOAT'
        BimTools::IfcManager::IfcReal.new(@ifc_model, value.to_f)
      else # (?) when "DEFAULT"
        if value.is_a? Length
          BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, value)
        elsif value.is_a? String
          BimTools::IfcManager::IfcLabel.new(@ifc_model, value)
        elsif value.is_a? Float
          BimTools::IfcManager::IfcReal.new(@ifc_model, value)
        end
      end
    end
  end
end
