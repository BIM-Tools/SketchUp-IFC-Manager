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
require_relative 'IfcBoolean.rb'
require_relative "IfcLabel.rb"
require_relative "IfcIdentifier.rb"
require_relative "IfcReal.rb"
require_relative "IfcInteger.rb"

require_relative File.join("dynamic_attributes.rb")
require_relative File.join("PropertyReader.rb")

module BimTools
  module IfcProduct_su
    include BimTools::IfcManager::Settings.ifc_module

    attr_accessor :su_object, :parent, :total_transformation, :type_product
    @su_object = nil
    @parent = nil
    
    def initialize(ifc_model, sketchup)
      @ifc_model = ifc_model
      super
      ifc_version = BimTools::IfcManager::Settings.ifc_version
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance) #(?) Is this check neccesary?
      
        @su_object = sketchup
        
        # get properties from su object and add them to ifc object
        definition = @su_object.definition

        #(?) set name, here? is this a duplicate?
        @name = BimTools::IfcManager::IfcLabel.new(definition.name)

        # also set "tag" to component instance name?
        # tag definition: The tag (or label) identifier at the particular instance of a product, e.g. the serial number, or the position number. It is the identifier at the occurrence level.
        
        if definition.attribute_dictionaries
          if definition.attribute_dictionaries[ifc_version]
            if props_ifc = definition.attribute_dictionaries[ifc_version].attribute_dictionaries
              props_ifc.each do |prop_dict|
                prop = prop_dict.name
                prop_sym = prop.to_sym
                if attributes.include? prop_sym

                  property_reader = BimTools::PropertyReader.new(prop_dict)
                  dict_value = property_reader.value
                  value_type = property_reader.value_type
                  attribute_type = property_reader.attribute_type
                  
                  if attribute_type == "choice"
                    # Skip this attribute, this is not a value but a reference
                  elsif attribute_type == "enumeration"
                    send("#{prop.downcase}=", dict_value)
                  else
                    entity_type = false
                    if value_type
                      begin
                        entity_type = BimTools::IfcManager.const_get(value_type)
                        value_entity = entity_type.new(dict_value)
                      rescue => e
                        puts "Error creating IfcProduct property type: #{self.class}, #{ e.to_s}"
                      end
                    end
                    unless entity_type
                      
                      case attribute_type
                      when "boolean"
                        value_entity = BimTools::IfcManager::IfcBoolean.new(dict_value)
                      when "double"
                        value_entity = BimTools::IfcManager::IfcReal.new(dict_value)
                      when "long"
                        value_entity = BimTools::IfcManager::IfcInteger.new(dict_value)
                      else # "string" and others?
                        value_entity = BimTools::IfcManager::IfcLabel.new(dict_value)
                      end
                    end
                    send("#{prop.downcase}=", value_entity)
                  end
                else
                  if prop_dict.attribute_dictionaries && prop_dict.name != "instanceAttributes"
                    reldef = IfcRelDefinesByProperties.new( ifc_model, prop_dict )
                    reldef.relatedobjects.add( self )
                  end
                end
              end
            end
          end
        end
        
        # set material if sketchup @su_object has a material
        if ifc_model.options[:materials]
          unless (self.is_a? IfcFeatureElementSubtraction)||(self.is_a? IfcVirtualElement)||(self.is_a? IfcSpatialStructureElement)
            if @su_object.material
              material_name = @su_object.material.display_name
            else
              material_name = "Default"
            end
              
            #check if materialassociation exists
            unless ifc_model.materials[material_name]
              
              # create new materialassociation
              ifc_model.materials[material_name] = IfcRelAssociatesMaterial.new(ifc_model, material_name)
            end
            
            #add self to materialassociation
            ifc_model.materials[material_name].relatedobjects.add( self )
          end
        end
        
        if ifc_model.options[:attributes]
          ifc_model.options[:attributes].each do | attr_dict_name |
            collect_psets( ifc_model, @su_object.definition.attribute_dictionary( attr_dict_name ) )
            collect_psets( ifc_model, @su_object.attribute_dictionary( attr_dict_name ) )
          end
        else
          if @su_object.definition.attribute_dictionaries
            @su_object.definition.attribute_dictionaries.each do | attr_dict |
              collect_psets( ifc_model, attr_dict )
            end
          end
          if @su_object.attribute_dictionaries
            @su_object.attribute_dictionaries.each do | attr_dict |
              collect_psets( ifc_model, attr_dict )
            end
          end
        end
        collect_classifications( ifc_model, definition )
        
        # collect dynamic component attributes if export option is set
        if ifc_model.options[:dynamic_attributes]
          BimTools::DynamicAttributes::get_dynamic_attributes( ifc_model, self )
        end
      end
    end

    # Add representation to the IfcProduct, transform geometry with given transformation
    # @param [Sketchup::Transformation] transformation
    def create_representation(faces, transformation, su_material)
      definition = @su_object.definition
      
      # set representation based on definition
      unless @representation
        @representation = IfcProductDefinitionShape.new(@ifc_model, definition)
      end

      representation = @representation.representations.first
        
      # Check if Mapped representation should be used
      if representation.representationtype.value == "MappedRepresentation"
        mapped_item = IfcMappedItem.new( @ifc_model )
        mappingsource = IfcRepresentationMap.new( @ifc_model )
        mappingtarget = IfcCartesianTransformationOperator3D.new( @ifc_model )
        mappingtarget.localorigin = IfcCartesianPoint.new( @ifc_model, Geom::Point3d.new )

        mappingsource.mappingorigin = IfcAxis2Placement3D.new( @ifc_model, transformation )
        mappingsource.mappingorigin.location = IfcCartesianPoint.new( @ifc_model, transformation.origin )
        mappingsource.mappingorigin.axis = IfcDirection.new( @ifc_model, transformation.zaxis )
        mappingsource.mappingorigin.refdirection = IfcDirection.new( @ifc_model, transformation.xaxis )

        mapped_item.mappingsource = mappingsource
        mapped_item.mappingtarget = mappingtarget

        mapped_representation = @ifc_model.mapped_representation?( definition )
        if !mapped_representation
          mapped_representation = IfcShapeRepresentation.new( @ifc_model , nil)
          brep = IfcFacetedBrep.new( @ifc_model, faces, Geom::Transformation.new(Geom::Point3d.new) )
          mapped_representation.items.add( brep )
          @ifc_model.add_mapped_representation( definition, mapped_representation )
        end
        
        mappingsource.mappedrepresentation = mapped_representation
        representation.items.add( mapped_item )
      else
        brep = IfcFacetedBrep.new( @ifc_model, faces, transformation )
        representation.items.add( brep )
      end
      
      # add color from su-object material, or a su_parent's
      if @ifc_model.options[:colors]
        IfcStyledItem.new( @ifc_model, brep, su_material )
      end
        
      # set layer
      if @ifc_model.options[:layers]
        
        #check if IfcPresentationLayerAssignment exists
        unless @ifc_model.layers[@su_object.layer.name]
          
          # create new IfcPresentationLayerAssignment
          @ifc_model.layers[@su_object.layer.name] = IfcPresentationLayerAssignment.new(@ifc_model, @su_object.layer)
        end
        
        #add self to IfcPresentationLayerAssignment
        @ifc_model.layers[@su_object.layer.name].assigneditems.add( @representation.representations.first )
      end
    end
    
    def collect_psets( ifc_model, attr_dict )
      if attr_dict.is_a? Sketchup::AttributeDictionary
        # get_properties and create propertysets for all nested attribute dictionaries
        # except for classifications
        unless attr_dict.name == "AppliedSchemaTypes" || ifc_model.su_model.classifications[ attr_dict.name ]
          reldef = IfcRelDefinesByProperties.new( ifc_model, attr_dict )
          reldef.relatedobjects.add( self )
          if attr_dict.attribute_dictionaries
            attr_dict.attribute_dictionaries.each do | sub_attr_dict |
              collect_psets( ifc_model, sub_attr_dict )
            end
          end
        end
      end
    end
    
    # add classifications    
    def collect_classifications( ifc_model, definition )
      su_model = ifc_model.su_model
      active_classifications = BimTools::IfcManager::Settings.classification_names
    
      # Collect all attached classifications except for IFC
      if definition.attribute_dictionaries
        definition.attribute_dictionaries.each do | attr_dict |
          if active_classifications.keys.include? attr_dict.name
            skc_reader = active_classifications[attr_dict.name]
              
            # Create classifications if they don't exist
            if ifc_model.classifications.keys.include?( attr_dict.name )
              ifc_classification = ifc_model.classifications[attr_dict.name]
            else
              ifc_classification = IfcClassification.new( ifc_model )
              ifc_model.classifications[attr_dict.name] = ifc_classification
              classification_properties = skc_reader.properties
              if classification_properties.key?("creator")
                ifc_classification.source = BimTools::IfcManager::IfcLabel.new(classification_properties.creator)
              end
              if classification_properties.key?("edition")
                ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(classification_properties.edition)
              end
              #ifc_classification.editiondate
              ifc_classification.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name )
            end

            attributes = []
            attr_dict.attribute_dictionaries.each do |attribute|
              attributes << attribute['value']
            end
            
            # No way to map values with certainty, just pick the first 2
            if attributes.length > 1
              ifc_classification_reference = ifc_classification.ifc_classification_references[ attributes[0] ]
              unless ifc_classification_reference
                ifc_classification_reference = IfcClassificationReference.new( ifc_model )
                #ifc_classification_reference.location = ""

                # Catch IFC4 changes
                if IfcClassificationReference.method_defined?(:itemreference)
                  ifc_classification_reference.itemreference = BimTools::IfcManager::IfcIdentifier.new(attributes[0])
                else
                  ifc_classification_reference.identification = BimTools::IfcManager::IfcIdentifier.new(attributes[0])
                end
                ifc_classification_reference.name = BimTools::IfcManager::IfcLabel.new(attributes[1])
                ifc_classification_reference.referencedsource = ifc_classification
                
                # add ifc_classification_reference to the list of references in the classification
                ifc_classification.ifc_classification_references[ attributes[0] ] = ifc_classification_reference
                
                # create IfcRelAssociatesClassification
                rel = IfcRelAssociatesClassification.new( ifc_model )
                rel.relatedobjects = BimTools::IfcManager::Ifc_Set.new( [self] )
                rel.relatingclassification = ifc_classification_reference
                ifc_classification_reference.ifc_rel_associates_classification = rel                    
              end
            end
          end

        end
      end
    end
    
    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split("::").last)
      super
    end
  end
end
