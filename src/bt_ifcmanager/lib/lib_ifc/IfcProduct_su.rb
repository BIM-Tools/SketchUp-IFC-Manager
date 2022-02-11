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
require_relative "IfcText.rb"
require_relative "IfcReal.rb"
require_relative "IfcInteger.rb"
require_relative "IfcLengthMeasure.rb"
require_relative "IfcPositiveLengthMeasure.rb"
require_relative "IfcPlaneAngleMeasure.rb"
require_relative "IfcThermalTransmittanceMeasure.rb"
require_relative "enumeration.rb"

# load entities
require_relative File.join("IFC2X3", "IfcLocalPlacement.rb")
require_relative File.join("IFC2X3", "IfcProductDefinitionShape.rb")
require_relative File.join("IFC2X3", "IfcRelAssociatesMaterial.rb")
require_relative File.join("IFC2X3", "IfcPresentationLayerAssignment.rb")
require_relative File.join("IFC2X3", "IfcRelDefinesByProperties.rb")
require_relative File.join("IFC2X3", "IfcClassification.rb")
require_relative File.join("IFC2X3", "IfcClassificationReference.rb")
require_relative File.join("IFC2X3", "IfcRelAssociatesClassification.rb")
require_relative File.join("IFC2X3", "IfcFacetedBrep.rb")
require_relative File.join("IFC2X3", "IfcStyledItem.rb")
require_relative File.join("IFC2X3", "IfcMappedItem.rb")
require_relative File.join("IFC2X3", "IfcRepresentationMap.rb")
require_relative File.join("IFC2X3", "IfcCartesianTransformationOperator3D.rb")

require_relative File.join("dynamic_attributes.rb")
require_relative File.join("PropertyReader.rb")

module BimTools
  module IfcProduct_su
    attr_accessor :su_object, :parent, :total_transformation
    @su_object = nil
    @parent = nil
    
    def initialize(ifc_model, sketchup)
      @ifc_model = ifc_model
      super
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance)
      
        @su_object = sketchup
        
        # get properties from su object and add them to ifc object
        definition = @su_object.definition
        
        #(?) set name, here? is this a duplicate?
        @name = BimTools::IfcManager::IfcLabel.new( definition.name )
        
        if definition.attribute_dictionaries
          if definition.attribute_dictionaries["IFC 2x3"]
            if props_ifc = definition.attribute_dictionaries["IFC 2x3"].attribute_dictionaries
              props_ifc.each do |prop_dict|
                prop = prop_dict.name
                prop_sym = prop.to_sym
                if properties.include? prop_sym

                  property_reader = BimTools::PropertyReader.new(prop_dict)
                  dict_value = property_reader.value
                  value_type = property_reader.value_type
                  attribute_type = property_reader.attribute_type
                  
                  if attribute_type == "choice"
                    # Skip this attribute, this is not a value but a reference
                  elsif attribute_type == "enumeration"
                    send("#{prop.downcase}=", BimTools::IfcManager::Enumeration.new(dict_value))
                  else
                    entity_type = false
                    if value_type
                      begin
                        # require_relative ent_type_name
                        entity_type = eval("BimTools::IfcManager::#{value_type}")
                        value_entity = entity_type.new(dict_value)
                      rescue => e
                        puts "Error creating IFC type: #{ e.to_s}"
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
                    reldef = BimTools::IFC2X3::IfcRelDefinesByProperties.new( ifc_model, prop_dict )
                    reldef.relatedobjects.add( self )
                  end
                end
              end
            end
          end
        end
        
        # set material if sketchup @su_object has a material
        if ifc_model.options[:materials]
          if @su_object.material
            material_name = @su_object.material.display_name
          else
            material_name = "Default"
          end
            
          #check if materialassociation exists
          unless ifc_model.materials[material_name]
            
            # create new materialassociation
            ifc_model.materials[material_name] = BimTools::IFC2X3::IfcRelAssociatesMaterial.new(ifc_model, material_name)
          end
          
          #add self to materialassociation
          ifc_model.materials[material_name].relatedobjects.add( self )
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
    end # def initialize

    # Add representation to the IfcProduct, transform geometry with given transformation
    # @param [Sketchup::Transformation] transformation
    def create_representation(faces, transformation, su_material)
      
      # set representation based on definition
      unless @representation
        @representation = BimTools::IFC2X3::IfcProductDefinitionShape.new(@ifc_model, @su_object.definition)
      end

      representation = @representation.representations.first
        
      # Check if Mapped representation should be used
      if representation.representationtype.value == "MappedRepresentation"
        mapped_item = BimTools::IFC2X3::IfcMappedItem.new( @ifc_model )
        mappingsource = BimTools::IFC2X3::IfcRepresentationMap.new( @ifc_model )
        mappingtarget = BimTools::IFC2X3::IfcCartesianTransformationOperator3D.new( @ifc_model )
        mappingtarget.localorigin = BimTools::IFC2X3::IfcCartesianPoint.new( @ifc_model, Geom::Point3d.new )

        mappingsource.mappingorigin = BimTools::IFC2X3::IfcAxis2Placement3D.new( @ifc_model, transformation )
        mappingsource.mappingorigin.location = BimTools::IFC2X3::IfcCartesianPoint.new( @ifc_model, transformation.origin )
        mappingsource.mappingorigin.axis = BimTools::IFC2X3::IfcDirection.new( @ifc_model, transformation.zaxis )
        mappingsource.mappingorigin.refdirection = BimTools::IFC2X3::IfcDirection.new( @ifc_model, transformation.xaxis )

        mapped_item.mappingsource = mappingsource
        mapped_item.mappingtarget = mappingtarget

        mapped_representation = @ifc_model.mapped_representation?( definition )
        if !mapped_representation
          mapped_representation = BimTools::IFC2X3::IfcShapeRepresentation.new( @ifc_model , nil)
          brep = BimTools::IFC2X3::IfcFacetedBrep.new( @ifc_model, faces, Geom::Transformation.new(Geom::Point3d.new) )
          mapped_representation.items.add( brep )
          @ifc_model.add_mapped_representation( definition, mapped_representation )
        end
        
        mappingsource.mappedrepresentation = mapped_representation
        representation.items.add( mapped_item )
      else
        brep = BimTools::IFC2X3::IfcFacetedBrep.new( @ifc_model, faces, transformation )
        representation.items.add( brep )
      end
      
      # add color from su-object material, or a su_parent's
      if @ifc_model.options[:styles]
        BimTools::IFC2X3::IfcStyledItem.new( @ifc_model, brep, su_material )
      end
        
      # set layer
      if @ifc_model.options[:layers]
        
        #check if IfcPresentationLayerAssignment exists
        unless @ifc_model.layers[@su_object.layer.name]
          
          # create new IfcPresentationLayerAssignment
          @ifc_model.layers[@su_object.layer.name] = BimTools::IFC2X3::IfcPresentationLayerAssignment.new(@ifc_model, @su_object.layer)
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
          reldef = BimTools::IFC2X3::IfcRelDefinesByProperties.new( ifc_model, attr_dict )
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
    
      # Collect all attached classifications except for IFC
      if definition.attribute_dictionaries
        definition.attribute_dictionaries.each do | attr_dict |

          #(mp) added if loop to temporarily allow only DIN 276-1 classification
          if attr_dict.name == "DIN 276-1" # unless attr_dict.name == "IFC 2x3"
            if su_model.classifications[ attr_dict.name ]
              
              # Create classifications if they don't exist
              if ifc_model.classifications.include?( attr_dict.name )
                cls = ifc_model.classifications[attr_dict.name]
              else
                cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                cls.source = BimTools::IfcManager::IfcLabel.new("DIN Deutsches Institut für Normung e.V.")
                cls.edition = BimTools::IfcManager::IfcLabel.new("2008-12")
                #cls.editiondate
                cls.name = BimTools::IfcManager::IfcLabel.new("DIN 276-1:2008-12")
              end
              
              # retrieve classification value from su object
              type = definition.get_attribute("AppliedSchemaTypes", attr_dict.name)
              if type
                code = definition.get_classification_value([attr_dict.name, type, "din_code"])
                text = definition.get_classification_value([attr_dict.name, type, "din_text"])
                
                # only create IfcClassificationReference if component has the code and text values for the classification
                if code && text
                  ifc_classification_reference = cls.ifc_classification_references[ code ]
                  unless ifc_classification_reference
                    ifc_classification_reference = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    #ifc_classification_reference.location = ""
                    ifc_classification_reference.itemreference = BimTools::IfcManager::IfcIdentifier.new(code)
                    ifc_classification_reference.name = BimTools::IfcManager::IfcLabel.new(text)
                    ifc_classification_reference.referencedsource = cls
                    
                    # add ifc_classification_reference to the list of references in the classification
                    cls.ifc_classification_references[ code ] = ifc_classification_reference
                    
                    # create IfcRelAssociatesClassification
                    assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    #assoc.name = ""
                    #assoc.description = ""
                    assoc.relatedobjects = BimTools::IfcManager::Ifc_Set.new( [self] )
                    assoc.relatingclassification = ifc_classification_reference
                    ifc_classification_reference.ifc_rel_associates_classification = assoc
                    
                  end
                end
              end
            end
          end #(mp) end of DIN 276-1 loop
          
          # temporarily allow only nlsfb classification
		  if attr_dict.name == "NL-SfB tabel 1 Classification"
            if su_model.classifications[ attr_dict.name ]
              
              # Create classifications if they don't exist
              if ifc_model.classifications.include?( attr_dict.name )
                cls = ifc_model.classifications[attr_dict.name]
              else
                cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                cls.source = BimTools::IfcManager::IfcLabel.new("BIM Loket")
                cls.edition = BimTools::IfcManager::IfcLabel.new("2005")
                #cls.editiondate
                cls.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name )
                
              end
              
              # retrieve classification value from su object
              type = definition.get_attribute("AppliedSchemaTypes", attr_dict.name)
              if type
                code = definition.get_classification_value([attr_dict.name, type, "Class-codenotatie"])
                text = definition.get_classification_value([attr_dict.name, type, "tekst_NL-SfB"])
                
                # only create IfcClassificationReference if component has the code and text values for the classification
                if code && text
                  ifc_classification_reference = cls.ifc_classification_references[ code ]
                  unless ifc_classification_reference
                    ifc_classification_reference = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    #ifc_classification_reference.location = ""
                    ifc_classification_reference.itemreference = BimTools::IfcManager::IfcIdentifier.new(code)
                    ifc_classification_reference.name = BimTools::IfcManager::IfcLabel.new(text)
                    ifc_classification_reference.referencedsource = cls
                    
                    # add ifc_classification_reference to the list of references in the classification
                    cls.ifc_classification_references[ code ] = ifc_classification_reference
                    
                    # create IfcRelAssociatesClassification
                    assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    #assoc.name = ""
                    #assoc.description = ""
                    assoc.relatedobjects = BimTools::IfcManager::Ifc_Set.new( [self] )
                    assoc.relatingclassification = ifc_classification_reference
                    ifc_classification_reference.ifc_rel_associates_classification = assoc
                    
                  end
                end
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
  end # module IfcProduct_su
end # module BimTools
