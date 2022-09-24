# frozen_string_literal: true

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

# load types
require_relative 'set'
require_relative 'IfcBoolean'
require_relative 'IfcInteger'
require_relative 'IfcLabel'
require_relative 'IfcLengthMeasure'
require_relative 'IfcReal'
require_relative 'IfcText'

require_relative 'ifc_property_builder'
require_relative 'ifc_rel_defines_by_properties_builder'

module BimTools
  module IfcManager
    # Reads the nested Sketchup AttributeDictionary structure for
    #  a Sketchup object classified as an IFC entity
    #
    # @param ifc_entity [IfcEntity]
    # @param attr_dict [Sketchup::AttributeDictionary]
    class IfcDictionaryReader
      INSTANCE_SET_NAME = 'SU_InstanceSet'
      DEFINITION_SET_NAME = 'SU_DefinitionSet'

      UNUSED_DICTS = %w[
        href
        ref
        proxy
        edo
        instanceAttributes
      ].freeze

      def initialize(ifc_model, ifc_entity, entity_dict, instance_class = nil)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        ifc_version = BimTools::IfcManager::Settings.ifc_version
        @ifc_model = ifc_model
        @ifc_entity = ifc_entity
        if entity_dict && entity_dict[ifc_version]
          @ifc_dict = entity_dict[ifc_version].attribute_dictionaries
        end
        @entity_dict = entity_dict
        @propertyset_names = []
        if @ifc_dict
          # split attributes from properties
          # First get property names
          # names = attr_dict.map(&:name)
          names = @ifc_dict.map { |x| x.name }
          names -= UNUSED_DICTS # filter out unwanted dictionaries
          ifc_entity_attributes = ifc_entity.attributes.map { |x| x.to_s }
          @attributes = names & ifc_entity_attributes

          # Skip IfcProduct-only attributes for IfcTypeProduct
          all_attributes = if instance_class
                             instance_class_attributes = instance_class.attributes.map { |x| x.to_s }
                             names & (ifc_entity_attributes + instance_class_attributes).uniq
                           else
                             @attributes
                           end

          @propertyset_names = names - all_attributes
        end
      end

      # Set the IFC entity attributes
      def set_attributes
        if @attributes
          i = 0
          while i < @attributes.length
            name = @attributes[i]
            value = set_attribute(@ifc_dict[name])
            i += 1
          end
        end
      end

      # Returns PropertySets and ElementQuantity's for this IFC entity
      #
      # @return [Array<Propertyset>]
      def get_propertysets
        @propertyset_names.select { |name| @ifc_dict[name] }.map do |name|
          get_propertyset(@ifc_dict[name])
        end
      end

      # add PropertySets and ElementQuantity's to this IFC entity through IfcRelDefinesByProperties
      #
      # @return [nil]
      def add_propertysets
        @propertyset_names.select { |name| @ifc_dict[name] }.map do |name|
          add_propertyset(@ifc_dict[name])
        end
        nil
      end

      def add_classifications
        if BimTools::IfcManager::Settings.export_classifications
          if schema_types = @entity_dict['AppliedSchemaTypes']
            schema_types.each do |classification_name, classification_value|

              # (?) exclude ALL IFC classifications?
              unless Settings.ifc_version == classification_name
                @ifc_model.classifications.add_classification_to_entity(@ifc_entity, classification_name, classification_value, @entity_dict[classification_name])
              end
            end
          end
        end
      end

      # Add the Sketchup properties SU_DefinitionSet
      #   if defined in settings attributes
      def add_sketchup_definition_properties(ifc_model, ifc_entity, sketchup, type_properties = false)
        attributes = ifc_model.options[:attributes]
        if attributes.include?(DEFINITION_SET_NAME) && (sketchup.attribute_dictionaries && (attr_dict = sketchup.attribute_dictionaries[DEFINITION_SET_NAME]))
          if propertyset = get_propertyset(attr_dict)
            if type_properties
              if ifc_entity.haspropertysets
                ifc_entity.haspropertysets.add(propertyset)
              else
                ifc_entity.haspropertysets = BimTools::IfcManager::Ifc_Set.new([propertyset])
              end
            else
              IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
                builder.set_relatingpropertydefinition(propertyset)
                builder.add_related_object(ifc_entity)
              end
            end
          end
        end
      end

      # Add the Sketchup properties SU_InstanceSet
      #   if defined in settings attributes
      def add_sketchup_instance_properties(ifc_model, ifc_entity, sketchup)
        attributes = ifc_model.options[:attributes]
        if attributes.include?(INSTANCE_SET_NAME) && (sketchup.attribute_dictionaries && (attr_dict = sketchup.attribute_dictionaries[INSTANCE_SET_NAME]))
          if propertyset = get_propertyset(attr_dict)
            IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
              builder.set_relatingpropertydefinition(propertyset)
              builder.add_related_object(ifc_entity)
            end
          end
        end
      end

      private

      def set_attribute(attr_dict)
        name = attr_dict.name

        # don't overwrite already set values
        return false unless @ifc_entity.send(name.downcase).nil?

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

      # Creates PropertySet if there are any properties to export
      #
      # @return [IfcPropertySet, IfcElementQuantity, False]
      def get_propertyset(attr_dict)
        if (attr_dict.name == 'BaseQuantities') || attr_dict.name.start_with?('Qto_') # export as elementquantities
          quantities = true
        else
          quantities = false
        end

        properties = []

        if pset_dicts = attr_dict.attribute_dictionaries
          names = pset_dicts.map { |x| x.name }
          names -= UNUSED_DICTS # filter out unwanted dictionaries

          # get the first dictionary (there should be only one left)
          names.each do |pset_dict_name|
            pset_dict = pset_dicts[pset_dict_name]
            property = Property.new(pset_dict)
            value = property.value
            ifc_type = property.ifc_type

            # Never set empty values
            next if value.nil? || (value.is_a?(String) && value.empty?)

            if quantities
              properties << IfcQuantityBuilder.build(@ifc_model, get_quantity_type(property.name)) do |builder|
                builder.set_name(property.name)
                builder.set_value(value)
              end
            else

              ifc_value = ifc_type.new(@ifc_model, value, true) if ifc_type

              # Check if IFC type is set, otherwise use basic types
              ifc_value ||= get_ifc_property_value(value, property.attribute_type, true)

              next unless ifc_value

              properties << IfcPropertyBuilder.build(@ifc_model, property.attribute_type) do |builder|
                builder.set_name(property.name)
                builder.set_value(ifc_value)
                builder.set_enumeration_reference(property.options) # in case of enumeration
              end
            end
          end

        else # Any other AttributeDictionaries like 'SU_DefinitionSet' and 'SU_InstanceSet'
          attr_dict.each do |key, value|
            next unless value
            next if value.is_a?(String) && value.empty?

            properties << IfcPropertyBuilder.build(@ifc_model) do |builder|
              builder.set_name(key)
              builder.set_value(get_ifc_property_value(value, nil, true))
            end
          end
        end

        if properties.empty?
          false
        else
          if quantities
            IfcElementQuantityBuilder.build(@ifc_model) do |builder|
              builder.set_name(attr_dict.name)
              builder.set_quantities(properties)
            end
          else
            IfcPropertySetBuilder.build(@ifc_model) do |builder|
              builder.set_name(attr_dict.name)
              builder.set_properties(properties)
            end
          end
        end
      end

      def add_propertyset(attr_dict)
        if propertyset = get_propertyset(attr_dict)
          IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
            builder.set_relatingpropertydefinition(propertyset)
            builder.add_related_object(@ifc_entity)
          end
        end
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
            BimTools::IfcManager::IfcLengthMeasure.new(@ifc_model, value, long, geometry=false)
          else # Map all others to string
            BimTools::IfcManager::IfcText.new(@ifc_model, value, long)
          end
        end
      end

      def get_quantity_type(name)
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

      def get_elementquantity(attr_dict)
        puts 'get_elementquantity'
        attr_dict.attribute_dictionaries.each do |qty_dict|
          puts qty_dict.name
        end

        quantities = attr_dict.attribute_dictionaries.map do |qty_dict|
          puts 'IfcQuantityBuilder'
          IfcQuantityBuilder.build(@ifc_model, get_quantity_type(qty_dict.name)) do |builder|
            builder.set_name(qty_dict.name)
            builder.set_value(qty_dict['value'])
          end
        end
        puts quantities
        if quantities.empty?
          false
        else
          IfcElementQuantityBuilder.build(@ifc_model) do |builder|
            builder.set_name(attr_dict.name)
            builder.set_quantities(quantities)
          end
        end
      end

      def add_elementquantity(attr_dict)
        puts 'add_elementquantity'
        propertyset = get_elementquantity(attr_dict)
        if propertyset
          rel_defines = @ifc::IfcRelDefinesByProperties.new(@ifc_model)
          rel_defines.relatingpropertydefinition = propertyset
          rel_defines
        else
          false
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
    end
  end

  # Collects the needed attributes for an IfcProperty from
  #  a nested Sketchup AttributeDictionary structure
  #
  # @param attr_dict [Sketchup::AttributeDictionary]
  #
  class Property
    attr_reader :name, :value, :ifc_type, :attribute_type, :options

    UNUSED_DICTS = %i[
      href
      ref
      proxy
      edo
      instanceAttributes
    ].freeze

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
        names = value_dicts.map { |x| x.name }
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
            names = subtype_dicts.map { |x| x.name }
            names -= UNUSED_DICTS # filter out unwanted dictionaries

            # there should be only one dictionary left
            if ifc_subtype_name = names.first
              subtype_dict = subtype_dicts[ifc_subtype_name]
              @value = subtype_dict['value']
              @options = subtype_dict['options']
            end
          end
        end
      end
    end
  end
end
