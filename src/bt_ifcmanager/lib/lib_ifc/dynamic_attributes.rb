# frozen_string_literal: true

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

require_relative 'ifc_types'
require_relative 'ifc_property_builder'
require_relative 'ifc_quantity_builder'
require_relative 'ifc_property_set_builder'
require_relative 'ifc_element_quantity_builder'

# method that collects all dynamic component attributes in the given objects and creates IfcPropertySets and Quantities

module BimTools
  module DynamicAttributes
    def self.get_dynamic_attributes(ifc_model, ifc_object)
      @ifc = IfcManager::Settings.ifc_module
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

          # IfcPropertySet
          when 'Pset', 'pset', 'CPset', 'cpset'
            unless pset_hash[pset_name]
              propertyset = IfcManager::IfcPropertySetBuilder.build(ifc_model) do |builder|
                builder.set_name(pset_name)
                builder.add_related_object(ifc_object)
              end
              pset_hash[pset_name] = propertyset
            end

            property = IfcManager::IfcPropertyBuilder.build(ifc_model) do |builder|
              builder.set_name(prop_name)
              builder.set_value(get_dynamic_attribute_value(instance, key))
            end
            pset_hash[pset_name].hasproperties.add(property)

          # IfcElementQuantity
          when 'Qto', 'Qty', 'BaseQuantities'
            pset_name = name_parts[0] if name_parts[0] == 'BaseQuantities'

            unless qty_hash[pset_name]
              propertyset = IfcManager::IfcElementQuantityBuilder.build(ifc_model) do |builder|
                builder.set_name(pset_name)
                builder.add_related_object(ifc_object)
              end
              qty_hash[pset_name] = propertyset
            end

            property = IfcManager::IfcQuantityBuilder.build(ifc_model) do |builder|
              builder.set_value(get_dynamic_attribute_value(instance, key, quantity = true))
              builder.set_name(prop_name)
            end
            qty_hash[pset_name].quantities.add(property)

          else

            # check if field is visible
            if %w[VIEW LIST TEXTBOX].include? attr_dict["_#{key}_access"]

              # create new PropertySet with name "SU_DynamicAttributes"
              pset_name = 'SU_DynamicAttributes'

              unless pset_hash[pset_name]
                propertyset = IfcManager::IfcPropertySetBuilder.build(ifc_model) do |builder|
                  builder.set_name(pset_name)
                  builder.add_related_object(ifc_object)
                end
                pset_hash[pset_name] = propertyset
              end

              property = IfcManager::IfcPropertyBuilder.build(ifc_model) do |builder|
                builder.set_name(prop_name)
                builder.set_value(get_dynamic_attribute_value(instance, key))
              end
              pset_hash[pset_name].hasproperties.add(property)
            end
          end
        end
      end
    end

    def self.get_quantity_type(name)
      case name.upcase
      when /AREA/
        :area
      when /VOLUME/
        :volume
      when /WEIGHT/
        :weight
      else # when /LENGTH/, /WIDTH/, /HEIGHT/, /DEPTH/, /PERIMETER/
        :length
      end
    end

    def self.get_dynamic_attribute_value(instance, key, quantity = false)
      # @todo optimize, only read instance data?
      dict = instance.definition.attribute_dictionary 'dynamic_attributes'
      instance_dict = instance.attribute_dictionary 'dynamic_attributes'

      # if instance value is empty, then use definition value
      value = if instance_dict && instance_dict[key]
                instance_dict[key]
              elsif dict && dict[key]
                dict[key]
              end

      # get unit, use "formulaunits" if possible, if not use "units"
      unless units = dict["_#{key}_formulaunits"]
        units = dict["_#{key}_units"]
      end

      case units
      when 'CENTIMETERS', 'INCHES'
        if quantity
          IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value, geometry=true)
        else
          IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value)
        end
      when 'STRING'
        IfcManager::Types::IfcLabel.new(@ifc_model, value)
      when 'FLOAT'
        IfcManager::Types::IfcReal.new(@ifc_model, value.to_f)
      else # (?) when "DEFAULT"
        if value.is_a? Length
          if quantity
            IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value, geometry=true)
          else
            IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value)
          end
        elsif value.is_a? String
          # @todo catch IfcText / IfcIdentifier?
          IfcManager::Types::IfcLabel.new(@ifc_model, value)
        elsif value.is_a? Float
          IfcManager::Types::IfcReal.new(@ifc_model, value.to_f)
        end
      end
    end
  end
end
