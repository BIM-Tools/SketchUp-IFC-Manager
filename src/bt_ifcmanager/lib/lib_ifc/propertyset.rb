#  propertyset.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'set'
require_relative 'list'
require_relative 'IfcAreaMeasure'
require_relative 'IfcBoolean'
require_relative 'IfcIdentifier'
require_relative 'IfcInteger'
require_relative 'IfcLabel'
require_relative 'IfcLengthMeasure'
require_relative 'IfcReal'
require_relative 'IfcText'
require_relative 'IfcVolumeMeasure'
require_relative 'ifc_rel_defines_by_properties_builder'

module BimTools
  module IfcManager
    module PropertyDictionary
      UNUSED_DICTS = %i[
        href
        ref
        proxy
        edo
        instanceAttributes
      ]

      def get_propertyset(attr_dict)
        # Create PropertySet if there are any properties to export
        properties = IfcManager::Ifc_Set.new

        if pset_dicts = attr_dict.attribute_dictionaries
          names = pset_dicts.map { |x| x.name.to_sym }
          names -= UNUSED_DICTS # filter out unwanted dictionaries

          # get the first dictionary (there should be only one left)
          names.each do |pset_dict_name|
            pset_dict = pset_dicts[pset_dict_name.to_s]
            property = Property.new(pset_dict)
            value = property.value
            ifc_type = property.ifc_type

            # Never set empty values
            next if value.nil? || (value.is_a?(String) && value.empty?)

            ifc_value = ifc_type.new(@ifc_model, value, true) if ifc_type

            # Check if IFC type is set, otherwise use basic types
            ifc_value ||= get_ifc_property_value(value, property.attribute_type, true)

            next unless ifc_value

            attribute_type = property.attribute_type

            if attribute_type == 'enumeration'
              ifc_property = @ifc::IfcPropertyEnumeratedValue.new(@ifc_model)
              if property.options
                enumeration_values = IfcManager::Ifc_List.new(property.options.map do |item|
                                                                BimTools::IfcManager::IfcLabel.new(@ifc_model, item,
                                                                                                   true)
                                                              end)
                if @ifc_model.property_enumerations.key?(property.name) && (@ifc_model.property_enumerations[property.name].enumerationvalues.step == enumeration_values.step)
                  prop_enum = @ifc_model.property_enumerations[property.name]
                else
                  prop_enum = @ifc::IfcPropertyEnumeration.new(@ifc_model)
                  prop_enum.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, property.name)
                  prop_enum.enumerationvalues = enumeration_values
                  @ifc_model.property_enumerations[property.name] = prop_enum
                end
                ifc_property.enumerationreference = prop_enum
              end
              ifc_value.long = true
              ifc_property.enumerationvalues = IfcManager::Ifc_List.new([ifc_value])
            else
              ifc_property = @ifc::IfcPropertySingleValue.new(@ifc_model)
              ifc_property.nominalvalue = ifc_value
            end
            ifc_property.name = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, property.name)
            properties << ifc_property
          end

        else # Any other AttributeDictionaries like 'SU_DefinitionSet' and 'SU_InstanceSet'
          attr_dict.each do |key, value|
            next unless value
            next if value.is_a?(String) && value.empty?

            prop = @ifc::IfcPropertySingleValue.new(@ifc_model)
            prop.name = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, key)
            prop.nominalvalue = get_ifc_property_value(value, nil, true)
            properties.add(prop)
          end
        end

        if properties.empty?
          false
        else
          propertyset = @ifc::IfcPropertySet.new(@ifc_model)
          propertyset.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, attr_dict.name)
          propertyset.hasproperties = properties
          propertyset
        end
      end

      def add_propertyset(attr_dict)
        if propertyset = get_propertyset(attr_dict)
          return IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
            builder.set_relatingpropertydefinition(propertyset)
          end
        end
        false
      end

      def get_ifc_property_value(value, attribute_type, long = false)
        case attribute_type
        when 'string'
          BimTools::IfcManager::IfcText.new(@ifc_model, value, long) # check string length?
        when 'boolean'
          BimTools::IfcManager::IfcBoolean.new(@ifc_model, value, long)
        when 'double'
          BimTools::IfcManager::IfcReal.new(@ifc_model, value, long)
        when 'long'
          BimTools::IfcManager::IfcInteger.new(@ifc_model, value, long)
        when 'choice'
          # Skip this attribute, this is not a value but a reference
          false
        when 'enumeration'
          if long
            BimTools::IfcManager::IfcLabel.new(@ifc_model, value, long)
          else
            value.to_sym
          end
        else
          case value
          when String
            BimTools::IfcManager::IfcText.new(@ifc_model, value, long) # check string length?
          when TrueClass
            BimTools::IfcManager::IfcBoolean.new(@ifc_model, value, long)
          when FalseClass
            BimTools::IfcManager::IfcBoolean.new(@ifc_model, value, long)
          when Float
            BimTools::IfcManager::IfcReal.new(@ifc_model, value, long)
          when Integer
            BimTools::IfcManager::IfcInteger.new(@ifc_model, value, long)
          when Length
            BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, value, long)
          else # Map all others to string
            BimTools::IfcManager::IfcText.new(@ifc_model, value, long)
          end
        end
      end

      def get_elementquantity(attr_dict)
        quantities = IfcManager::Ifc_Set.new
        attr_dict.attribute_dictionaries.each do |qty_dict|
          next unless qty_dict['value']

          case qty_dict.name.upcase
          when /AREA/
            prop = @ifc::IfcQuantityArea.new(@ifc_model, attr_dict)
            prop.name = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, qty_dict.name)
            prop.areavalue = BimTools::IfcManager::IfcAreaMeasure.new(@ifc_model, qty_dict['value'])
            quantities.add(prop)
          when /VOLUME/
            prop = @ifc::IfcQuantityVolume.new(@ifc_model, attr_dict)
            prop.name = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, qty_dict.name)
            prop.volumevalue = BimTools::IfcManager::IfcVolumeMeasure.new(@ifc_model, qty_dict['value'])
            quantities.add(prop)
          when /LENGTH/, /WIDTH/, /HEIGHT/, /DEPTH/, /PERIMETER/
            prop = @ifc::IfcQuantityLength.new(@ifc_model, attr_dict)
            prop.name = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, qty_dict.name)
            prop.lengthvalue = BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, qty_dict['value'])
            quantities.add(prop)
          end
        end

        # Create ElementQuantity if there are any quantities to export
        if quantities.empty?
          false
        else
          elementquantity = @ifc::IfcElementQuantity.new(@ifc_model, attr_dict)
          elementquantity.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, attr_dict.name)
          elementquantity.quantities = quantities
          elementquantity
        end
      end

      def add_elementquantity(attr_dict)
        propertyset = get_elementquantity(attr_dict)
        if propertyset
          rel_defines = @ifc::IfcRelDefinesByProperties.new(@ifc_model)
          rel_defines.relatingpropertydefinition = propertyset
          rel_defines
        else
          false
        end
      end

      # Add the Sketchup properties SU_DefinitionSet
      #   if defined in settings attributes
      def add_sketchup_definition_properties(ifc_model, ifc_entity, sketchup, type_properties = false)
        attributes = ifc_model.options[:attributes]
        if attributes.include? 'SU_DefinitionSet' && (sketchup.attribute_dictionaries && dict = sketchup.attribute_dictionaries['SU_DefinitionSet'])
          if type_properties
            propertyset = get_propertyset(dict)
            ifc_entity.haspropertysets.add(propertyset) if propertyset
          else
            rel_defines = add_propertyset(dict)
            rel_defines.relatedobjects.add(ifc_entity) if rel_defines
          end
        end
      end

      # Add the Sketchup properties SU_InstanceSet
      #   if defined in settings attributes
      def add_sketchup_instance_properties(ifc_model, ifc_entity, sketchup)
        attributes = ifc_model.options[:attributes]
        if attributes.include? 'SU_InstanceSet' && (sketchup.attribute_dictionaries && dict = sketchup.attribute_dictionaries['SU_InstanceSet'])
          rel_defines = add_propertyset(dict)
          rel_defines.relatedobjects.add(ifc_entity) if rel_defines
        end
      end
    end
  end
end
