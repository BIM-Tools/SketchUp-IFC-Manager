#  IfcTypeProduct_su.rb
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
require_relative 'list'
require_relative 'IfcGloballyUniqueId'
require_relative 'IfcLabel'

module BimTools
  module IfcTypeProduct_su
    attr_accessor :su_object

    # @param sketchup [Sketchup::ComponentDefinition]
    def initialize(ifc_model, definition, ifc_product)
      super(ifc_model, definition)
      @ifc = BimTools::IfcManager::Settings.ifc_module
      @definition = definition
      ifc_version = BimTools::IfcManager::Settings.ifc_version
      @propertysets = BimTools::IfcManager::Ifc_Set.new

      @rel_defines_by_type = @ifc::IfcRelDefinesByType.new(@ifc_model)
      @rel_defines_by_type.relatingtype = self
      @rel_defines_by_type.relatedobjects = BimTools::IfcManager::Ifc_Set.new

      # (!) duplicate code with IfcProduct_su

      @name = BimTools::IfcManager::IfcLabel.new(ifc_model, definition.name)
      @globalid = BimTools::IfcManager::IfcGloballyUniqueId.new(definition)

      # (?) set "tag" to component instance name?
      # tag definition: The tag (or label) identifier at the particular instance of a product, e.g. the serial number, or the position number. It is the identifier at the occurrence level.

      # get attributes from su object and add them to IfcTypeProduct
      if definition.attribute_dictionaries && definition.attribute_dictionaries[ifc_version] && props_ifc = definition.attribute_dictionaries[ifc_version].attribute_dictionaries
        dict_reader = BimTools::IfcManager::IfcDictionaryReader.new(ifc_model, self, props_ifc)
        dict_reader.set_attributes()
      end

      if ifc_model.options[:attributes]
        ifc_model.options[:attributes].each do |attr_dict_name|
          collect_psets(ifc_model, @definition.attribute_dictionary(attr_dict_name))
        end
      elsif @definition.attribute_dictionaries
        @definition.attribute_dictionaries.each do |attr_dict|
          collect_psets(ifc_model, attr_dict)
        end
      end

      # (?) Disable use of haspropertysets for Vico compatibility?
      # # Only set property when not empty
      # if @propertysets.length > 0
      #   @haspropertysets = @propertysets
      # end

      # Set PredefinedType to default value when not set
      if defined?(predefinedtype) && @predefinedtype.nil?
        @predefinedtype = :notdefined
      end

      collect_classifications(ifc_model, definition)
    end

    def add_typed_object(product)
      @rel_defines_by_type.relatedobjects.add(product)
    end

    def collect_psets(ifc_model, attr_dict)
      if attr_dict.is_a?(Sketchup::AttributeDictionary) && !((attr_dict.name == 'AppliedSchemaTypes') || ifc_model.su_model.classifications[attr_dict.name])
        rel_defines = BimTools::IfcManager.create_propertyset(ifc_model, attr_dict)

        # (?) Disable use of haspropertysets for Vico compatibility?
        @propertysets.add(rel_defines) if rel_defines
        # rel_defines.relatedobjects.add(self) if rel_defines
        if attr_dict.attribute_dictionaries
          attr_dict.attribute_dictionaries.each do |sub_attr_dict|
            collect_psets(ifc_model, sub_attr_dict)
          end
        end
      end
    end

    # add classifications
    def collect_classifications(ifc_model, definition)
      su_model = ifc_model.su_model
      active_classifications = BimTools::IfcManager::Settings.classification_names

      # Collect all attached classifications except for IFC
      if definition.attribute_dictionaries
        definition.attribute_dictionaries.each do |attr_dict|
          next unless active_classifications.keys.include? attr_dict.name

          skc_reader = active_classifications[attr_dict.name]

          # Create classifications if they don't exist
          if ifc_model.classifications.keys.include?(attr_dict.name)
            ifc_classification = ifc_model.classifications[attr_dict.name]
          else
            ifc_classification = @ifc::IfcClassification.new(ifc_model)
            ifc_model.classifications[attr_dict.name] = ifc_classification
            classification_properties = skc_reader.properties

            creator = classification_properties[:creator]
            if creator && !creator.empty?
              ifc_classification.source = BimTools::IfcManager::IfcLabel.new(ifc_model, creator)
            end

            edition = classification_properties[:revision]
            if edition && !edition.empty?
              ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(ifc_model, edition)
            end

            editiondate = classification_properties[:modified]
            if editiondate && !editiondate.empty?
              ifc_classification.editiondate = BimTools::IfcManager::IfcLabel.new(ifc_model, editiondate)
            end

            ifc_classification.name = BimTools::IfcManager::IfcLabel.new(ifc_model, attr_dict.name)
          end

          attributes = []
          attr_dict.attribute_dictionaries.each do |attribute|
            attributes << attribute['value']
          end

          # No way to map values with certainty, just pick the first 2
          next unless attributes.length > 1

          ifc_classification_reference = ifc_classification.ifc_classification_references[attributes[0]]
          next if ifc_classification_reference

          ifc_classification_reference = @ifc::IfcClassificationReference.new(ifc_model)
          # ifc_classification_reference.location = ""

          # Catch IFC4 changes
          if @ifc::IfcClassificationReference.method_defined?(:itemreference)
            ifc_classification_reference.itemreference = BimTools::IfcManager::IfcIdentifier.new(ifc_model,
                                                                                                 attributes[0])
          else
            ifc_classification_reference.identification = BimTools::IfcManager::IfcIdentifier.new(ifc_model,
                                                                                                  attributes[0])
          end
          ifc_classification_reference.name = BimTools::IfcManager::IfcLabel.new(ifc_model, attributes[1])
          ifc_classification_reference.referencedsource = ifc_classification

          # add ifc_classification_reference to the list of references in the classification
          ifc_classification.ifc_classification_references[attributes[0]] = ifc_classification_reference

          # create IfcRelAssociatesClassification
          rel = @ifc::IfcRelAssociatesClassification.new(ifc_model)
          rel.relatedobjects = BimTools::IfcManager::Ifc_Set.new([self])
          rel.relatingclassification = ifc_classification_reference
          ifc_classification_reference.ifc_rel_associates_classification = rel
        end
      end
    end
  end
end
