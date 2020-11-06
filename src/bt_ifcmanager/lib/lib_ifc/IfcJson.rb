#  IfcJson.rb
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

# mixin module to set the JSON generation methods for all IFC classes
 
module BimTools
  module IfcJson
     def to_json(arg=nil)
       json_hash = {"type" => self.class.name.split('::').last}
       properties = properties()
       properties.each do |property_name|
         # property = self.send(property_name.downcase)
        #  if property_name == :OwnerHistory || property_name == :RepresentationContexts || property_name == :UnitsInContext || property_name == :ObjectPlacement
           
           # puts property.class.name
           # json_hash[property_name] = {"ref" => property.globalid}
           # if property.is_a? String
           #   output << property
           # elsif property.is_a?(IfcManager::IfcGloballyUniqueId) || property.is_a?(IfcManager::Ifc_Set) || property.is_a?(IfcManager::Ifc_Type) || property.is_a?(IfcManager::IfcReal)
           #   output << property.step
           # else
           #   line << "##{property.ifc_id}"
           # end
        #  else
           # puts "%"<< property_name << "%"
           value = self.send(property_name.downcase)

           # Camelize property name
           name_camel = property_name.to_s
           name_camel[0] = name_camel[0].downcase
 
           # only include non empty properties
           unless(value.nil?) || (value=="")
             json_hash[property_name] = value
           end
        #  end
       end
      #  if @isdecomposedby
      #    json_hash["IsDecomposedBy"] = @isdecomposedby
      #  end
       json_string = json_hash.to_json()
      #  if(@isdefinedby)&&(@isdefinedby.to_json.length > 2)
      #    isdefinedby = @isdefinedby.to_json.sub("},{", ",")
      #    json_string = json_string[0..-2] << "," << isdefinedby[2..-2]# << "}"
 
      #    # # # merge object-properties with isdefinedby-properties, if duplicate, keep object-property
      #    # # # json_hash.merge(@isdefinedby.items){|key, property, isdefinedby| property}
      #    # @isdefinedby.items.each do |propertyset|
      #    # #   properties = propertyset.relatingpropertydefinition.hasproperties()
      #    # #   properties.each do |property_name|
      #    # #     puts property_name
      #    # #     # value = self.send(property_name.downcase)
 
      #    # #     # # only include non empty properties
      #    # #     # unless(value.nil?) || (value=="")
      #    # #     #   json_hash[property_name] = value
      #    # #     # end
      #    #   puts propertyset.to_hash
      #    #   json_hash.merge(propertyset.to_hash){|key, property, isdefinedby| property}
      #    # #   end
      #    # end
      #  end
       return json_string
     end # to_json
  end # module IfcJson
 end # module BimTools
 