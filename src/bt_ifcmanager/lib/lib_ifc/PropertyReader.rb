#  PropertyReader.rb
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

module BimTools
  module IfcManager

    # Reads the nested Sketchup AttributeDictionary structure for
    #  a Sketchup object classified as an IFC entity
    #
    # @parameter ifc_entity [IfcEntity]
    # @parameter attr_dict [Sketchup::AttributeDictionary]
    #
    # Reads the Sketchup AttributeDictionary for an IFC classification
    class IfcDictionaryReader
      UNUSED_DICTS = %i[
        href
        ref
        proxy
        edo
        instanceAttributes
      ]
      def initialize(ifc_model, ifc_entity, ifc_dict)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        # split attributes from properties
        # First get property names
        # names = attr_dict.map(&:name)
        @ifc_model = ifc_model
        @ifc_entity = ifc_entity
        @ifc_dict = ifc_dict
        names = ifc_dict.map { |x| x.name.to_sym }
        names -= UNUSED_DICTS # filter out unwanted dictionaries
        @attributes = names & ifc_entity.attributes
        @propertyset_names = names - @attributes
      end

      def set_attributes
        i = 0
        while i < @attributes.length
          name = @attributes[i].to_s
          value = set_attribute(@ifc_dict[name])
          i += 1
        end
      end

      def get_propertysets
        propertysets = []
        i = 0
        while i < @propertyset_names.length
          name = @propertyset_names[i].to_s
          # value = if quantity?(name) # check hier? of aan het eind na beoordelen alle properties?
          # propertysets << get_elementquantity(@ifc_dict[name])
          # else
          propertysets << get_propertyset(@ifc_dict[name])
          # end

          i += 1
        end
        propertysets
      end

      private

      def set_attribute(attr_dict)
        name = attr_dict.name

        # don't overwrite already set values
        return false unless @ifc_entity.send(name.downcase.to_s).nil?

        property = Property.new(attr_dict)
        value = property.value
        ifc_type = property.ifc_type

        # Never set empty values
        return false if value.nil? || (value.is_a?(String) && value.empty?)

        ifc_value = ifc_type.new(@ifc_model, value) if ifc_type

        # Check if IFC type is set, otherwise use basic types
        ifc_value ||= get_ifc_property_value(value, property.attribute_type)
        return @ifc_entity.send("#{name.downcase}=", ifc_value) if ifc_value
      end

      def get_ifc_physical_quantity(value, attribute_type); end

      def get_ifc_property_value(value, attribute_type, long = false)
        case attribute_type
        when 'string'
          BimTools::IfcManager::IfcLabel.new(@ifc_model, value, long) # check string length?
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
            BimTools::IfcManager::IfcLabel.new(@ifc_model, value, long) # check string length?
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
            BimTools::IfcManager::IfcLabel.new(@ifc_model, value, long)
          end
        end
      end

      def get_property_value(attr_dict); end

      def get_propertyset(attr_dict)
        if pset_dicts = attr_dict.attribute_dictionaries
          names = pset_dicts.map { |x| x.name.to_sym }
          names -= UNUSED_DICTS # filter out unwanted dictionaries

          # Create PropertySet if there are any properties to export
          properties = IfcManager::Ifc_Set.new

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
            unless ifc_value
              ifc_value = get_ifc_property_value(value, property.attribute_type, true)
            end

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

          unless properties.empty?
            propertyset = @ifc::IfcPropertySet.new(@ifc_model)
            propertyset.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, attr_dict.name)
            propertyset.hasproperties = properties
            rel_defines = @ifc::IfcRelDefinesByProperties.new(@ifc_model)
            rel_defines.relatingpropertydefinition = propertyset
            rel_defines
          end
        end
      end

      def get_elementquantity(attr_dict); end
    end
  end

  # Collects the needed attributes for an IfcProperty from
  #  a nested Sketchup AttributeDictionary structure
  #
  # @parameter attr_dict [Sketchup::AttributeDictionary]
  #
  class Property
    attr_reader :name, :value, :ifc_type, :attribute_type, :options

    UNUSED_DICTS = %i[
      href
      ref
      proxy
      edo
      instanceAttributes
    ]

    def initialize(attr_dict)
      @name = attr_dict.name

      # When value is set the data is stored on this level
      @value = attr_dict['value']
      @attribute_type = attr_dict['attribute_type']

      # We can't be sure that the unspecified false value is meant as a boolean or
      #  is just imported as an empty value from an IFC file
      #  skip to prevent wrong assumptions
      if !@attribute_type && (@value == false)
        @value = nil
        return false
      end

      # enumerations have options lists
      @options = attr_dict['options']

      # When no value in first level than look in the second level of attribute dictionaries
      #   these next level attribute dictionaries normally have an IFC type as name
      #   like: path = ["IFC 2x3", "IfcWindow", "Name", "IfcLabel"]
      if !value && attr_dict.attribute_dictionaries
        value_dicts = attr_dict.attribute_dictionaries
        names = value_dicts.map { |x| x.name.to_sym }
        names -= UNUSED_DICTS # filter out unwanted dictionaries

        # there should be only one dictionary left
        if ifc_type_name = names.first
          value_dict = attr_dict.attribute_dictionaries[ifc_type_name.to_s]
          @value = value_dict['value']
          @attribute_type = value_dict['attribute_type']
          @options = value_dict['options']

          # Check for IFC type
          if ifc_type_name[0].upcase == ifc_type_name[0] && BimTools::IfcManager.const_defined?(ifc_type_name)
            @ifc_type = BimTools::IfcManager.const_get(ifc_type_name)
          end

          # Sometimes the value is even nested a level deeper
          #   like: path = ["IFC 2x3", "IfcWindow", "OverallWidth", "IfcPositiveLengthMeasure", "IfcLengthMeasure"]
          #   (!) This deepest level does not contain the ifc_type we need!
          if !@value && value_dict.attribute_dictionaries
            subtype_dicts = value_dict.attribute_dictionaries
            names = subtype_dicts.map { |x| x.name.to_sym }
            names -= UNUSED_DICTS # filter out unwanted dictionaries

            # there should be only one dictionary left
            if ifc_subtype_name = names.first
              subtype_dict = subtype_dicts[ifc_subtype_name.to_s]
              @value = subtype_dict['value']
              @options = subtype_dict['options']
            end
          end
        end
      end
    end
  end
end
