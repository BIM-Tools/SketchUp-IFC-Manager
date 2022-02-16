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

require_relative 'propertyset'

module BimTools
  module IfcManager
    # Reads the nested Sketchup AttributeDictionary structure for
    #  a Sketchup object classified as an IFC entity
    #
    # @param ifc_entity [IfcEntity]
    # @param attr_dict [Sketchup::AttributeDictionary]
    class IfcDictionaryReader
      include BimTools::IfcManager::PropertyDictionary

      def initialize(ifc_model, ifc_entity, entity_dict, instance_class = nil)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        ifc_version = BimTools::IfcManager::Settings.ifc_version
        @ifc_model = ifc_model
        @ifc_entity = ifc_entity
        @ifc_dict = entity_dict[ifc_version].attribute_dictionaries if entity_dict && entity_dict[ifc_version]
        @entity_dict = entity_dict
        if @ifc_dict
          # split attributes from properties
          # First get property names
          # names = attr_dict.map(&:name)
          names = @ifc_dict.map { |x| x.name.to_sym }
          names -= UNUSED_DICTS # filter out unwanted dictionaries
          @attributes = names & ifc_entity.attributes

          # Skip IfcProduct-only attributes for IfcTypeProduct
          all_attributes = if instance_class
                             names & (ifc_entity.attributes + instance_class.attributes).uniq
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
            name = @attributes[i].to_s
            value = set_attribute(@ifc_dict[name])
            i += 1
          end
        end
      end

      # Collect all propertysets for this object
      #
      # @return [Array<Propertyset>]
      def get_propertysets
        propertysets = []
        if @propertyset_names
          i = 0
          while i < @propertyset_names.length
            name = @propertyset_names[i].to_s
            propertyset = if (name == 'BaseQuantities') || name.start_with?('Qto_') # export as elementquantities
                            get_elementquantity(@ifc_dict[name])
                          else
                            get_propertyset(@ifc_dict[name])
                          end
            propertysets << propertyset if propertyset
            i += 1
          end
        end
        propertysets
      end

      def add_propertysets
        if @propertyset_names
          i = 0
          while i < @propertyset_names.length
            name = @propertyset_names[i].to_s
            rel_defines = if (name == 'BaseQuantities') || name.start_with?('Qto_') # export as elementquantities
                            add_elementquantity(@ifc_dict[name])
                          else
                            add_propertyset(@ifc_dict[name])
                          end
            rel_defines.relatedobjects.add(@ifc_entity) if rel_defines
            i += 1
          end
        end
      end

      def add_classifications
        active_classifications = BimTools::IfcManager::Settings.classification_names

        # Collect all attached classifications except for IFC
        @entity_dict.each do |attr_dict|
          next unless active_classifications.keys.include? attr_dict.name

          skc_reader = active_classifications[attr_dict.name]

          # Create classifications if they don't exist
          if @ifc_model.classifications.keys.include?(attr_dict.name)
            ifc_classification = @ifc_model.classifications[attr_dict.name]
          else
            ifc_classification = @ifc::IfcClassification.new(@ifc_model)
            @ifc_model.classifications[attr_dict.name] = ifc_classification
            classification_properties = skc_reader.properties

            creator = classification_properties[:creator]
            if creator && !creator.empty?
              ifc_classification.source = BimTools::IfcManager::IfcLabel.new(@ifc_model, creator)
            end

            edition = classification_properties[:revision]
            if edition && !edition.empty?
              ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(@ifc_model, edition)
            end

            editiondate = classification_properties[:modified]
            if editiondate && time = Time.parse(editiondate)

              # Catch IFC4 changes
              if @ifc.const_defined?(:IfcCalendarDate)
                date = @ifc::IfcCalendarDate.new(@ifc_model)
                date.daycomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.day)
                date.monthcomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.month)
                date.yearcomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.year)
                ifc_classification.editiondate = date
              else
                ifc_classification.editiondate = BimTools::IfcManager::IfcDate.new(@ifc_model, time)
              end
            end
            if @ifc_model.options[:classification_suffix]
              ifc_classification.name = BimTools::IfcManager::IfcLabel.new(@ifc_model,
                                                                           attr_dict.name << ' Classification')
            else
              ifc_classification.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, attr_dict.name)
            end
          end

          attributes = []
          attr_dict.attribute_dictionaries.each do |attribute|
            attributes << attribute['value']
          end

          # No way to map values with certainty, just pick the first 2
          next unless attributes.length > 1

          classification_ref = ifc_classification.ifc_classification_references[attributes[0]]
          unless classification_ref
            classification_ref = @ifc::IfcClassificationReference.new(@ifc_model)
            classification_ref.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, attributes[1])
            classification_ref.referencedsource = ifc_classification

            # add classification_ref to the list of references in the classification
            ifc_classification.ifc_classification_references[attributes[0]] = classification_ref

            # Catch IFC4 atrribute name change
            identification = BimTools::IfcManager::IfcIdentifier.new(@ifc_model, attributes[0])
            if @ifc::IfcClassificationReference.method_defined?(:itemreference)
              classification_ref.itemreference = identification
            else
              classification_ref.identification = identification
            end

            # create IfcRelAssociatesClassification
            rel = @ifc::IfcRelAssociatesClassification.new(@ifc_model)
            rel.relatedobjects = BimTools::IfcManager::Ifc_Set.new
            rel.relatingclassification = classification_ref
            classification_ref.ifc_rel_associates_classification = rel
          end
          classification_ref.ifc_rel_associates_classification.relatedobjects.add(@ifc_entity)
        end
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
