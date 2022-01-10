#  IfcProduct_su.rb
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

# load types
require_relative 'IfcBoolean'
require_relative 'IfcLabel'
require_relative 'IfcIdentifier'
require_relative 'IfcReal'
require_relative 'IfcInteger'
require_relative 'IfcText'

require_relative 'propertyset'

require_relative File.join('dynamic_attributes.rb')
require_relative File.join('PropertyReader.rb')

module BimTools
  module IfcProduct_su
    attr_accessor :su_object, :parent, :total_transformation, :type_product

    @su_object = nil
    @parent = nil

    def initialize(ifc_model, sketchup)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module

      # Check if this is an empty object (default object) or based on a Sketchup::ComponentInstance or Sketchup::Group
      if sketchup.respond_to?(:definition)

        ifc_version = BimTools::IfcManager::Settings.ifc_version
        @ifc_model = ifc_model
        @su_object = sketchup
        definition = @su_object.definition

        # Set IfcProductType
        if @ifc_model.product_types.key?(definition)
          @type_product = @ifc_model.product_types[definition]
          @type_product.add_typed_object(self)
        end

        # (?) set "tag" to component instance name?
        # tag definition: The tag (or label) identifier at the particular instance of a product, e.g. the serial number, or the position number. It is the identifier at the occurrence level.

        # get attributes from su object and add them to IfcProduct
        if definition.attribute_dictionaries && definition.attribute_dictionaries[ifc_version] && props_ifc = definition.attribute_dictionaries[ifc_version].attribute_dictionaries
          props_ifc.each do |prop_dict|
            prop = prop_dict.name
            if attributes.include? prop.to_sym

              if prop['value']
                dict_value = prop['value']
                value_type = nil
                attribute_type = nil
              else
                property_reader = BimTools::PropertyReader.new(prop_dict)
                dict_value = property_reader.value
                value_type = property_reader.value_type
                attribute_type = property_reader.attribute_type
              end

              # Don't fill empty properties
              next if dict_value.nil? || (dict_value.is_a?(String) && dict_value.empty?)

              if attribute_type == 'choice'
                # Skip this attribute, this is not a value but a reference
              elsif attribute_type == 'enumeration'
                send("#{prop.downcase}=", dict_value.to_sym)
              else
                entity_type = false
                if value_type
                  begin
                    valid_type = BimTools::IfcManager.const_defined?(value_type)
                  rescue NameError
                    # Skip all attributes that cannot be converted to a constant
                    next
                  end

                  if valid_type
                    entity_type = BimTools::IfcManager.const_get(value_type)
                    value_entity = entity_type.new(ifc_model, dict_value)
                  end
                else
                  value_entity = case attribute_type
                                 when 'boolean'
                                   BimTools::IfcManager::IfcBoolean.new(ifc_model, dict_value)
                                 when 'double'
                                   BimTools::IfcManager::IfcReal.new(ifc_model, dict_value)
                                 when 'long'
                                   BimTools::IfcManager::IfcInteger.new(ifc_model, dict_value)
                                 else # "string" and others?
                                   BimTools::IfcManager::IfcLabel.new(ifc_model, dict_value)
                                 end
                end
                send("#{prop.downcase}=", value_entity)
              end
            elsif !@type_product && (prop_dict.attribute_dictionaries && prop_dict.name != 'instanceAttributes')
              if propertyset = BimTools::IfcManager.create_propertyset(ifc_model, prop_dict)
                rel_defines = @ifc::IfcRelDefinesByProperties.new(ifc_model)
                rel_defines.relatingpropertydefinition = propertyset
                rel_defines.relatedobjects.add(self)
              end
            end
          end
        end

        # (?) set name, here? is this a duplicate?
        @name = BimTools::IfcManager::IfcLabel.new(ifc_model, @su_object.name)

        # set material if sketchup @su_object has a material
        # Material added to Product and not to TypeProduct because a Sketchup ComponentDefinition can have a different material for every Instance
        if ifc_model.options[:materials] && !((is_a? @ifc::IfcFeatureElementSubtraction) || (is_a? @ifc::IfcVirtualElement) || (is_a? @ifc::IfcSpatialStructureElement))
          material_name = if @su_object.material
                            @su_object.material.display_name
                          else
                            'Default'
                          end

          # check if materialassociation exists
          unless ifc_model.materials[material_name]

            # create new materialassociation
            ifc_model.materials[material_name] = @ifc::IfcRelAssociatesMaterial.new(ifc_model, material_name)

          end

          # add self to materialassociation
          ifc_model.materials[material_name].relatedobjects.add(self)
          # puts ifc_model.materials[material_name].step
        end

        # collect dynamic component attributes if export option is set
        BimTools::DynamicAttributes.get_dynamic_attributes(ifc_model, self) if ifc_model.options[:dynamic_attributes]

        if ifc_model.options[:attributes]
          ifc_model.options[:attributes].each do |attr_dict_name|
            # Only add propertysets when no type
            collect_psets(ifc_model, @su_object.definition.attribute_dictionary(attr_dict_name)) unless @type_product
            collect_psets(ifc_model, @su_object.attribute_dictionary(attr_dict_name))
          end
        else

          # Only add definition propertysets when no TypeProduct is set
          if !@type_product && @su_object.definition.attribute_dictionaries
            @su_object.definition.attribute_dictionaries.each do |attr_dict|
              collect_psets(ifc_model, attr_dict)
            end
          end
          if @su_object.attribute_dictionaries
            @su_object.attribute_dictionaries.each do |attr_dict|
              collect_psets(ifc_model, attr_dict)
            end
          end
        end
        collect_classifications(ifc_model, definition)
      end
    end

    # Add representation to the IfcProduct, transform geometry with given transformation
    # @param [Sketchup::Transformation] transformation
    def create_representation(definition, faces, transformation, su_material)
      definition = @su_object.definition

      # '@representation' is set to IfcLabel as default because the Sketchup attribute value is ''

      # set representation based on definition
      @representation = @ifc::IfcProductDefinitionShape.new(@ifc_model, definition)

      shape_representation = @representation.representations.first

      # Check if Mapped representation should be used
      if shape_representation.representationtype.value == 'MappedRepresentation'
        mapped_item = @ifc::IfcMappedItem.new(@ifc_model)
        target = @ifc::IfcCartesianTransformationOperator3D.new(@ifc_model)
        target.localorigin = @ifc::IfcCartesianPoint.new(@ifc_model, Geom::Point3d.new)
        definition_manager = @ifc_model.representation_manager.get_definition_manager(definition)
        definition_representation = definition_manager.get_representation(faces, transformation, su_material)
        mapped_item.mappingsource = definition_representation.representationmap
        mapped_item.mappingtarget = target
        shape_representation.items.add(mapped_item)
      else
        brep = @ifc::IfcFacetedBrep.new(@ifc_model, faces, transformation)
        shape_representation.items.add(brep)

        # add color from su-object material, or a su_parent's
        @ifc::IfcStyledItem.new(@ifc_model, brep, su_material) if @ifc_model.options[:colors]
      end

      # set layer
      if @ifc_model.options[:layers]

        # check if IfcPresentationLayerAssignment exists
        unless @ifc_model.layers[@su_object.layer.name]

          # create new IfcPresentationLayerAssignment
          @ifc_model.layers[@su_object.layer.name] =
            @ifc::IfcPresentationLayerAssignment.new(@ifc_model, @su_object.layer)
        end

        # add self to IfcPresentationLayerAssignment
        @ifc_model.layers[@su_object.layer.name].assigneditems.add(shape_representation)
      end
    end

    def collect_psets(ifc_model, attr_dict)
      if attr_dict.is_a?(Sketchup::AttributeDictionary) && !(attr_dict.name == 'AppliedSchemaTypes' || ifc_model.su_model.classifications[attr_dict.name])
        rel_defines = BimTools::IfcManager.create_propertyset(ifc_model, attr_dict)
        rel_defines.relatedobjects.add(self) if rel_defines
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
            if classification_properties.key?('creator') && !classification_properties.creator.empty?
              ifc_classification.source = BimTools::IfcManager::IfcLabel.new(ifc_model,
                                                                             classification_properties.creator)
            # Workaround mandatory value for IFC2x3
            elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'
              ifc_classification.source = BimTools::IfcManager::IfcLabel.new(ifc_model, 'unknown')
            end
            if classification_properties.key?('edition') && !classification_properties.edition.empty?
              ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(ifc_model,
                                                                              classification_properties.edition)

            # Workaround mandatory value for IFC2x3
            elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'
              ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(ifc_model, 'unknown')
            end
            if classification_properties.key?('editiondate') && !classification_properties.editiondate.empty?
              ifc_classification.editiondate = BimTools::IfcManager::IfcLabel.new(ifc_model,
                                                                              classification_properties.editiondate)
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

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end
end
