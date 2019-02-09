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

require_relative File.join('IFC2X3', 'IfcLocalPlacement.rb')
require_relative File.join('IFC2X3', 'IfcProductDefinitionShape.rb')
require_relative File.join('IFC2X3', 'IfcRelAssociatesMaterial.rb')
require_relative File.join('IFC2X3', 'IfcPresentationLayerAssignment.rb')
require_relative File.join('IFC2X3', 'IfcRelDefinesByProperties.rb')
require_relative File.join('IFC2X3', 'IfcClassification.rb')
require_relative File.join('IFC2X3', 'IfcClassificationReference.rb')
require_relative File.join('IFC2X3', 'IfcRelAssociatesClassification.rb')
require_relative File.join('dynamic_attributes.rb')

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
          if definition.attribute_dictionaries['IFC 2x3']
            if props_ifc = definition.attribute_dictionaries['IFC 2x3'].attribute_dictionaries
              props_ifc.each do |prop_dict|
                prop = prop_dict.name
                prop_sym = prop.to_sym
                if properties.include? prop_sym
                  
                  # get data for objects with additional nesting levels
                  # like: path = ["IFC 2x3", "IfcWindow", "OverallWidth", "IfcPositiveLengthMeasure", "IfcLengthMeasure"]
                  val_dict = return_value_dict( prop_dict )
                  if value = val_dict["value"]
                    
                    # create the proper type based on the dictionary name
                    case val_dict.name
                    when "IfcText"
                      send("#{prop.downcase}=", "'#{val_dict["value"]}'")
                    when "IfcLabel"
                      send("#{prop.downcase}=", "'#{val_dict["value"]}'")
                    when "IfcIdentifier"
                      send("#{prop.downcase}=", "'#{val_dict["value"]}'")
                    when "IfcLengthMeasure"
                      send("#{prop.downcase}=", val_dict["value"].to_f.to_s)
                    end
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
        
        # (!) fill predefinedtype, needs more work
        if @predefinedtype.nil?
          @predefinedtype = '.NOTDEFINED.'
        end

        # set representation based on definition
        @representation = BimTools::IFC2X3::IfcProductDefinitionShape.new(ifc_model, sketchup.definition)
        
        # set material if sketchup @su_object has a material
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
        
        # set layer
        #check if IfcPresentationLayerAssignment exists
        unless ifc_model.layers[@su_object.layer.name]
          
          # create new IfcPresentationLayerAssignment
          ifc_model.layers[@su_object.layer.name] = BimTools::IFC2X3::IfcPresentationLayerAssignment.new(ifc_model, @su_object.layer)
        end
        
        #add self to IfcPresentationLayerAssignment
        ifc_model.layers[@su_object.layer.name].assigneditems.add( @representation.representations.first )
        
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
    
    # find the dictionary containing "value" field
    def return_value_dict( dict )
      
      # if a field "value" exists then we are at the data level and data can be retrieved, otherwise dig deeper
      if dict["value"]
        return dict
      else
        dict.attribute_dictionaries.each do | sub_dict |
          unless sub_dict.name == "instanceAttributes"
            return return_value_dict( sub_dict )
          end
        end
      end
    end # def return_value_dict
    
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
        
# # create classifications from su_model
# def create_classifications()
  # classifications = Array.new
  # @su_model.classifications.each { |schema|
    
    # # create any classification except for IFC
    # unless schema.name == 'IFC 2x3'
      # classification = BimTools::IFC2X3::IfcClassification.new( self )
      # classification.source = ''
      # classification.edition = ''
      # classification.name = "'" + schema.name + "'"
      # classifications << classification
      
      # # special options for nlsfb
      # if schema.name == 'NL-SfB 2005, tabel 1'
        # classification.source = "'BIM-Loket'"
        # classification.edition = "'2005'"
        # unicode = BimTools::IFC2X3::IfcClassification.new( self )
        # unicode.source = "'http://www.csiorg.net/uniformat'"
        # unicode.edition = "'1998'"
        # unicode.name = "'Uniformat'"
        # classifications << unicode
      # end
    # end
  # }
  # return classifications
# end # def create_classifications

          #(mp) added if loop to temporarily allow only DIN 276-1 classification
          if attr_dict.name == 'DIN 276-1' # unless attr_dict.name == 'IFC 2x3'
            if su_model.classifications[ attr_dict.name ]
              
              # Create classifications if they don't exist
              if ifc_model.classifications.include?( attr_dict.name )
                cls = ifc_model.classifications[attr_dict.name]
              else
                cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                cls.source = "'DIN Deutsches Institut für Normung e.V.'"
                cls.edition = "'2008-12'"
                #cls.editiondate
                cls.name = "'DIN 276-1:2008-12'"
                
                # vico hack: store a copy of DIN 276-1 as unicode
                unicode_cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                unicode_cls.source = "'http://www.csiorg.net/uniformat'"
                unicode_cls.edition = "'1998'"
                #unicode_cls.editiondate
                unicode_cls.name = "'Uniformat'"
              end
              
              # retrieve classification value from su object
              type = definition.get_attribute('AppliedSchemaTypes', attr_dict.name)
              if type
                code = definition.get_classification_value([attr_dict.name, type, 'din_code'])
                text = definition.get_classification_value([attr_dict.name, type, 'din_text'])
                
                # only create IfcClassificationReference if component has the code and text values for the classification
                if code && text
                  ifc_classification_reference = cls.ifc_classification_references[ code ]
                  unless ifc_classification_reference
                    ifc_classification_reference = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    #ifc_classification_reference.location = ''
                    ifc_classification_reference.itemreference = "'#{code}'"
                    ifc_classification_reference.name = "'#{text}'"
                    ifc_classification_reference.referencedsource = cls
                    
                    # add ifc_classification_reference to the list of references in the classification
                    cls.ifc_classification_references[ code ] = ifc_classification_reference
                    
                    # create IfcRelAssociatesClassification
                    assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    #assoc.name = ''
                    #assoc.description = ''
                    assoc.relatedobjects = BimTools::IfcManager::Ifc_Set.new( [self] )
                    assoc.relatingclassification = ifc_classification_reference
                    ifc_classification_reference.ifc_rel_associates_classification = assoc
                    
                    # vico hack: store a copy of DIN 276-1 as unicode
                    unicode_din_text = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    unicode_din_text.location = "'http://www.csiorg.net/uniformat'"
                    unicode_din_text.itemreference = "'#{code}'"
                    unicode_din_text.name = "'#{text}'"
                    unicode_din_text.referencedsource = unicode_cls
                    unicode_assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    unicode_assoc.name = "'DIN 276-1:2008-12, Uniformat Classification'"
                    #unicode_assoc.description = ''
                    unicode_assoc.relatedobjects = IfcManager::Ifc_Set.new( [self] )
                    unicode_assoc.relatingclassification = unicode_din_text
                    unicode_din_text.ifc_rel_associates_classification = unicode_assoc
                    
                  end
                end
              end
            end
          end #(mp) end of DIN 276-1 loop
          
          # temporarily allow only nlsfb classification
          if attr_dict.name == 'NL-SfB 2005, tabel 1' # unless attr_dict.name == 'IFC 2x3'
            if su_model.classifications[ attr_dict.name ]
              
              # Create classifications if they don't exist
              if ifc_model.classifications.include?( attr_dict.name )
                cls = ifc_model.classifications[attr_dict.name]
              else
                cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                cls.source = "'BIM Loket'"
                cls.edition = "'2005'"
                #cls.editiondate
                cls.name = "'#{attr_dict.name}'"
                
                # vico hack: store a copy of NL-SfB as unicode
                unicode_cls = BimTools::IFC2X3::IfcClassification.new( ifc_model )
                unicode_cls.source = "'http://www.csiorg.net/uniformat'"
                unicode_cls.edition = "'1998'"
                #unicode_cls.editiondate
                unicode_cls.name = "'Uniformat'"
              end
              
              # retrieve classification value from su object
              type = definition.get_attribute('AppliedSchemaTypes', attr_dict.name)
              if type
                code = definition.get_classification_value([attr_dict.name, type, 'Class-codenotatie'])
                tekst = definition.get_classification_value([attr_dict.name, type, 'tekst_NL-SfB'])
                
                # only create IfcClassificationReference if component has the code and text values for the classification
                if code && tekst
                  ifc_classification_reference = cls.ifc_classification_references[ code ]
                  unless ifc_classification_reference
                    ifc_classification_reference = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    #ifc_classification_reference.location = ''
                    ifc_classification_reference.itemreference = "'#{code}'"
                    ifc_classification_reference.name = "'#{tekst}'"
                    ifc_classification_reference.referencedsource = cls
                    
                    # add ifc_classification_reference to the list of references in the classification
                    cls.ifc_classification_references[ code ] = ifc_classification_reference
                    
                    # create IfcRelAssociatesClassification
                    assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    #assoc.name = ''
                    #assoc.description = ''
                    assoc.relatedobjects = BimTools::IfcManager::Ifc_Set.new( [self] )
                    assoc.relatingclassification = ifc_classification_reference
                    ifc_classification_reference.ifc_rel_associates_classification = assoc
                    
                    # vico hack: store a copy of NL-SfB as unicode
                    unicode_reference = BimTools::IFC2X3::IfcClassificationReference.new( ifc_model )
                    unicode_reference.location = "'http://www.csiorg.net/uniformat'"
                    unicode_reference.itemreference = "'#{code}'"
                    unicode_reference.name = "'#{tekst}'"
                    unicode_reference.referencedsource = unicode_cls
                    unicode_assoc = BimTools::IFC2X3::IfcRelAssociatesClassification.new( ifc_model )
                    unicode_assoc.name = "'Uniformat Classification'"
                    #unicode_assoc.description = ''
                    unicode_assoc.relatedobjects = IfcManager::Ifc_Set.new( [self] )
                    unicode_assoc.relatingclassification = unicode_reference
                    unicode_reference.ifc_rel_associates_classification = unicode_assoc
                    
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
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end # module IfcProduct_su
end # module BimTools
