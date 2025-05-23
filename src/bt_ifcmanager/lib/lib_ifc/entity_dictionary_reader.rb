# frozen_string_literal: true

#  entity_dictionary_reader.rb
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

require_relative 'ifc_types'
require_relative 'ifc_property_builder'
require_relative 'ifc_rel_defines_by_properties_builder'
require_relative 'property_dictionary_reader'

module BimTools
  module IfcManager
    # Reads the nested Sketchup AttributeDictionary structure for
    #  a Sketchup object classified as an IFC entity
    #
    # @param [IfcEntity] ifc_entity
    # @param [Sketchup::AttributeDictionary] attr_dict
    class EntityDictionaryReader
      INSTANCE_SET_NAME = 'SU_InstanceSet'
      DEFINITION_SET_NAME = 'SU_DefinitionSet'

      UNUSED_DICTS = %w[
        href
        ref
        proxy
        edo
        instanceAttributes
        Classifications
        PropertySets
      ].freeze

      CLASSIFICATION_ATTRIBUTES = %w[
        Location
        ItemReference
        Identification
        Name
        ReferencedSource
        Description
        Sort
        Definition
        RelatedIfcEntityNames
      ].freeze

      # Define a mapping for attributes that need to be renamed
      ATTRIBUTE_MAPPING = {
        'ObjectType' => 'ElementType'
      }.freeze

      def initialize(ifc_model, ifc_entity, entity_dict, instance_class = nil)
        @ifc_module = ifc_model.ifc_module
        @ifc_version = ifc_model.ifc_version
        @ifc_model = ifc_model
        @ifc_entity = ifc_entity
        @instance_class = instance_class
        @ifc_dict = entity_dict[@ifc_version].attribute_dictionaries if entity_dict && entity_dict[@ifc_version]
        @entity_dict = entity_dict
        @propertyset_names = []
        return unless @ifc_dict

        ifc_entity_attributes = ifc_entity.attributes.map { |x| x.to_s }
        ifc_entity_inverse_attributes = ifc_entity.inverse_attributes.map { |x| x.to_s }

        # split attributes from properties
        names = @ifc_dict.map(&:name)
        names -= UNUSED_DICTS # filter out unwanted dictionaries
        names -= ifc_entity_inverse_attributes # filter out inverse dictionaries
        @attributes = names & ifc_entity_attributes

        # Skip IfcProduct-only attributes for IfcTypeProduct
        @all_attributes = if instance_class
                            instance_class_attributes = instance_class.attributes.map { |x| x.to_s }
                            names & (ifc_entity_attributes + instance_class_attributes).uniq
                          else
                            @attributes
                          end

        @propertyset_names = names - @all_attributes - ifc_entity_inverse_attributes
      end

      # Set the IFC entity attributes using all combined attribute possibilitites from IfcProduct and IfcTypeProduct
      def set_attributes
        return unless @all_attributes

        i = 0
        while i < @all_attributes.length
          name = @all_attributes[i]
          value = @ifc_dict[name]
          set_attribute(value)
          i += 1
        end
      end

      # Returns PropertySets for this IFC entity
      #
      # @return [Array<Propertyset>]
      def get_propertysets
        return [] unless @ifc_dict && @entity_dict && @entity_dict['AppliedSchemaTypes']

        applied_schema_types = @entity_dict['AppliedSchemaTypes']
        propertysets = []

        applied_schema_types.keys.each do |schema_type|
          next unless @entity_dict[schema_type]

          schema_dict = @entity_dict[schema_type]
          schema_dict.attribute_dictionaries.each do |attribute_dictionary|
            if attribute_dictionary.name == 'PropertySets'
              next unless attribute_dictionary.attribute_dictionaries

              attribute_dictionary.attribute_dictionaries.each do |propertysets_attribute_dictionary|
                propertysets << get_propertyset(propertysets_attribute_dictionary)
              end
            elsif attribute_dictionary.name == 'Classifications'
              next
            elsif Settings.ifc_version_names.include?(schema_dict.name)
              if @propertyset_names.include? attribute_dictionary.name
                propertysets << get_propertyset(attribute_dictionary)
              end
            else
              next if CLASSIFICATION_ATTRIBUTES.include?(attribute_dictionary.name)

              propertysets << get_propertyset(attribute_dictionary)
            end
          end
        end

        propertysets.compact
      end

      # Adds PropertySets to this IFC entity through IfcRelDefinesByProperties
      #
      # @return [nil]
      def add_propertysets
        get_propertysets.each do |propertyset|
          add_propertyset(propertyset)
        end
        nil
      end

      def add_classifications
        unless IfcManager::Settings.export_classifications && schema_types = @entity_dict['AppliedSchemaTypes']
          return
        end

        schema_types.each do |classification_name, classification_value|
          next if Settings.ifc_version_names.include?(classification_name)

          @ifc_model.classifications.add_classification_to_entity(
            @ifc_entity,
            classification_name,
            classification_value,
            @entity_dict[classification_name]
          )
        end
      end

      # Add the Sketchup properties SU_DefinitionSet
      #   if defined in settings attributes
      def add_sketchup_definition_properties(ifc_model, ifc_entity, sketchup, type_properties = false)
        attributes = ifc_model.options[:attributes]
        unless attributes.include?(DEFINITION_SET_NAME) && (sketchup.attribute_dictionaries && (attr_dict = sketchup.attribute_dictionaries[DEFINITION_SET_NAME])) && propertyset = get_propertyset(attr_dict)
          return
        end

        if type_properties
          if ifc_entity.haspropertysets
            ifc_entity.haspropertysets.add(propertyset)
          else
            ifc_entity.haspropertysets = IfcManager::Types::Set.new([propertyset])
          end
        else
          IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
            builder.set_relatingpropertydefinition(propertyset)
            builder.add_related_object(ifc_entity)
          end
        end
      end

      # Add the Sketchup properties SU_InstanceSet
      #   if defined in settings attributes
      def add_sketchup_instance_properties(ifc_model, ifc_entity, sketchup)
        attributes = ifc_model.options[:attributes]
        if attributes.include?(INSTANCE_SET_NAME) && (sketchup.attribute_dictionaries && (attr_dict = sketchup.attribute_dictionaries[INSTANCE_SET_NAME])) && propertyset = get_propertyset(attr_dict)
          IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
            builder.set_relatingpropertydefinition(propertyset)
            builder.add_related_object(ifc_entity)
          end
        end
      end

      private

      def handle_predefined_type(value)
        if value == 'userdefined'
          object_type_or_element_type = @ifc_dict['ObjectType'] || @ifc_dict['ElementType']
          return :notdefined if object_type_or_element_type
        end
        return value if value.is_a?(Symbol)

        value.is_a?(String) ? value.to_sym : value.value.to_sym # TODO: hacky fix
      end

      def set_attribute(attr_dict)
        name = determine_name(attr_dict)
        return false unless valid_attribute?(name)

        property = create_property(attr_dict, name)
        value = property.value

        return false if value.nil? || (value.is_a?(String) && value.empty?)

        ifc_value = determine_ifc_value(property, value)
        ifc_value = handle_predefined_type(ifc_value) if name == 'PredefinedType'

        @ifc_entity.send("#{name.downcase}=", ifc_value) if ifc_value
      end

      def determine_name(attr_dict)
        name = attr_dict.name
        @instance_class ? (ATTRIBUTE_MAPPING[name] || name) : name
      end

      def valid_attribute?(name)
        @ifc_entity.respond_to?(name.downcase) && @ifc_entity.send(name.downcase).nil?
      end

      def create_property(attr_dict, name)
        @instance_class ? PropertyDictionaryReader.new(attr_dict, name) : PropertyDictionaryReader.new(attr_dict)
      end

      def determine_ifc_value(property, value)
        ifc_type = property.ifc_type
        ifc_type ? ifc_type.new(@ifc_model, value) : get_ifc_property_value(value, property.attribute_type)
      end

      # Creates PropertySet if there are any properties to export
      #
      # @return [IfcPropertySet, IfcElementQuantity, False]
      def get_propertyset(attr_dict)
        quantities = if (attr_dict.name == 'BaseQuantities') || attr_dict.name.start_with?('Qto_') # export as elementquantities
                       true
                     else
                       false
                     end

        properties = []

        if pset_dicts = attr_dict.attribute_dictionaries
          names = pset_dicts.map { |x| x.name }
          names -= UNUSED_DICTS # filter out unwanted dictionaries

          # get the first dictionary (there should be only one left)
          names.each do |pset_dict_name|
            pset_dict = pset_dicts[pset_dict_name]
            property = PropertyDictionaryReader.new(pset_dict)
            value = property.value
            ifc_type = property.ifc_type

            # Never set empty values
            next if value.nil? || (value.is_a?(String) && value.empty?)

            if quantities

              if value
                case get_quantity_type(property.name)
                when :length
                  ifc_value = IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value, long = false, geometry = false)
                when :area
                  ifc_value = IfcManager::Types::IfcAreaMeasure.new(@ifc_model, value)
                when :volume
                  ifc_value = IfcManager::Types::IfcVolumeMeasure.new(@ifc_model, value)
                when :weight
                  ifc_value = IfcManager::Types::IfcMassMeasure.new(@ifc_model, value)
                end
              end

              next unless ifc_value

              properties << IfcQuantityBuilder.build(@ifc_model) do |builder|
                builder.set_value(ifc_value)
                builder.set_name(property.name)
              end
            else

              if ifc_type
                # Check if ifc_type is a subclass of IfcLengthMeasure
                ifc_value = if ifc_type <= BimTools::IfcManager::Types::IfcLengthMeasure
                              ifc_type.new(@ifc_model, value, true, false)
                            else
                              ifc_type.new(@ifc_model, value, true)
                            end
              end

              # Check if IFC type is set, otherwise use basic types
              if !ifc_value || !ifc_value.is_a?(IfcManager::Types::BaseType)
                ifc_value = get_ifc_property_value(value, property.attribute_type, true)
              end

              next unless ifc_value

              properties << IfcPropertyBuilder.build(@ifc_model, property.attribute_type) do |builder|
                builder.set_name(property.name)
                builder.set_value(ifc_value)
                if property.attribute_type == :enumeration
                  builder.set_enumeration_reference(
                    property.options,
                    property.ifc_type_name
                  )
                end
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
        elsif quantities
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

      def add_propertyset(propertyset)
        IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
          builder.set_relatingpropertydefinition(propertyset)
          builder.add_related_object(@ifc_entity)
        end
      end

      def get_ifc_property_value(value, attribute_type, long = false)
        case attribute_type
        when :string
          IfcManager::Types::IfcText.new(@ifc_model, value, long) # check string length?
        when :boolean
          IfcManager::Types::IfcBoolean.new(@ifc_model, value, long)
        when :double
          IfcManager::Types::IfcReal.new(@ifc_model, value, long)
        when :long
          IfcManager::Types::IfcInteger.new(@ifc_model, value, long)
        when :choice
          # Skip this attribute, this is not a value but a reference
          false
        when :enumeration
          if long
            IfcManager::Types::IfcLabel.new(@ifc_model, value, long)
          else
            value.to_sym
          end
        else
          case value
          when String
            IfcManager::Types::IfcText.new(@ifc_model, value, long) # check string length?
          when TrueClass
            IfcManager::Types::IfcBoolean.new(@ifc_model, value, long)
          when FalseClass
            IfcManager::Types::IfcBoolean.new(@ifc_model, value, long)
          when Float
            IfcManager::Types::IfcReal.new(@ifc_model, value, long)
          when Integer
            IfcManager::Types::IfcInteger.new(@ifc_model, value, long)
          when Length
            IfcManager::Types::IfcLengthMeasure.new(@ifc_model, value, long, geometry = false)
          else # Map all others to string
            IfcManager::Types::IfcText.new(@ifc_model, value, long)
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
end
