#  IfcRelDefinesByProperties_su.rb
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

require_relative 'set.rb'
require_relative 'IfcLabel.rb'
require_relative 'IfcIdentifier.rb'
require_relative 'IfcText.rb'
require_relative 'IfcBoolean.rb'
require_relative File.join('IFC2X3', 'IfcPropertySet.rb')
require_relative File.join('IFC2X3', 'IfcPropertySingleValue.rb')
require_relative File.join('IFC2X3', 'IfcElementQuantity.rb')
require_relative File.join('IFC2X3', 'IfcQuantityArea.rb')
require_relative File.join('IFC2X3', 'IfcQuantityVolume.rb')
require_relative File.join('IFC2X3', 'IfcQuantityLength.rb')

module BimTools
  module IfcRelDefinesByProperties_su
    def initialize(ifc_model, sketchup)
    
      # (!) this should be automatically created by root!!!
      @globalid = IfcManager::IfcGloballyUniqueId.new()
      @ownerhistory = ifc_model.owner_history
      
      @relatedobjects = IfcManager::Ifc_Set.new()
      if sketchup.is_a?( Sketchup::AttributeDictionary )
        attr_dict = sketchup
        if attr_dict.name == "BaseQuantities" # export as elementquantities
          
          qty = BimTools::IFC2X3::IfcElementQuantity.new( ifc_model, attr_dict )
          @relatingpropertydefinition = qty
          qty.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name ) unless attr_dict.name.nil?
          qty.quantities = IfcManager::Ifc_Set.new()
          attr_dict.attribute_dictionaries.each { | dict |
            case dict.name
            when "Area", "GrossArea"
              prop = BimTools::IFC2X3::IfcQuantityArea.new( ifc_model, attr_dict )
              prop.name = BimTools::IfcManager::IfcIdentifier.new( dict.name )
              prop.areavalue = BimTools::IfcManager::IfcReal.new( dict['value'] ) # real should be IfcLengthMeasure
              qty.quantities.add( prop )
            when "Volume"
              prop = BimTools::IFC2X3::IfcQuantityVolume.new( ifc_model, attr_dict )
              prop.name = BimTools::IfcManager::IfcIdentifier.new( dict.name )
              prop.volumevalue = BimTools::IfcManager::IfcReal.new( dict['value'] ) # real should be IfcLengthMeasure
              qty.quantities.add( prop )
            when "Width", "Height", "Depth", "Perimeter"
              prop = BimTools::IFC2X3::IfcQuantityLength.new( ifc_model, attr_dict )
              prop.name = BimTools::IfcManager::IfcIdentifier.new( dict.name )
              prop.lengthvalue = BimTools::IfcManager::IfcReal.new( dict['value'] ) # real should be IfcLengthMeasure
              qty.quantities.add( prop )
            #else
            end
          }
          
        else # export as propertyset
          pset = BimTools::IFC2X3::IfcPropertySet.new( ifc_model, attr_dict )
          @relatingpropertydefinition = pset
          pset.name = BimTools::IfcManager::IfcLabel.new( attr_dict.name ) unless attr_dict.name.nil?
          pset.hasproperties = IfcManager::Ifc_Set.new()

          # removed check for attr_dict length due to the fact the sketchup classifier always adds is_hidden property
          if attr_dict.attribute_dictionaries# && attr_dict.length == 0
            attr_dict.attribute_dictionaries.each { | dict |
              
              prop = BimTools::IFC2X3::IfcPropertySingleValue.new( ifc_model, attr_dict )
              prop.name = BimTools::IfcManager::IfcIdentifier.new( dict.name )
              
              # get value type
              case dict['attribute_type']
              when "double"
                prop.nominalvalue = BimTools::IfcManager::IfcReal.new( dict['value'] )
              when "boolean"
                prop.nominalvalue = BimTools::IfcManager::IfcBoolean.new( dict['value'] )
              #when "string"
              #  prop.nominalvalue = BimTools::IfcManager::IfcLabel.new( dict['value'] ) # (!) not always IfcLabel
              else
                prop.nominalvalue = BimTools::IfcManager::IfcLabel.new( dict['value'] ) # (!) not always IfcLabel
              end
              prop.nominalvalue.long = true # adding long = true returns a full object string, necessary for propertyset
              pset.hasproperties.add( prop )
            }
          else
            attr_dict.each { | key, value |
              prop = BimTools::IFC2X3::IfcPropertySingleValue.new( ifc_model, attr_dict )
              prop.name = BimTools::IfcManager::IfcIdentifier.new( key )
              prop.nominalvalue = BimTools::IfcManager::IfcLabel.new( value ) # (!) not always IfcLabel
              prop.nominalvalue.long = true # adding long = true returns a full object string
              pset.hasproperties.add( prop )
            }
          end
        end
      end
    end # def sketchup
  end # module IfcRelDefinesByProperties_su
end # module BimTools
