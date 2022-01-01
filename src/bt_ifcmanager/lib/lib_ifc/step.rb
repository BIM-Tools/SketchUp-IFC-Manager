#  step.rb
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

# mixin module to set the Step generation methods for all IFC classes
 
module BimTools
  module Step

    # Returns the STEP representation for an object
    #
    # @return String
    #
    def step()
      attribute_strings = attributes().map { |attribute| attribute_to_step(attribute) }
      return "##{@ifc_id}=#{self.class.name.split('::').last.upcase}(#{attribute_strings.join(",")})"
    end

    # Returns the STEP representation for an attribute
    #
    # @param property_name
    #
    # @return String
    #
    def attribute_to_step(property_name)
      property = self.send(property_name.downcase)
      case property
      when nil
        return "$"
      when String
        return property
      when TrueClass
        return ".T."
      when FalseClass
        return ".F."
      when IfcManager::IfcGloballyUniqueId, IfcManager::Ifc_List, IfcManager::Ifc_Set, IfcManager::Ifc_Type
        return property.step
      else
        return property.ref
      end
    end

    # Instead of the full step object return a STEP reference
    #   for example '#15'
    #
    # @return String
    #
    def ref()
      if !@ifc_id
        raise "Missing IFC object ID for: #{self}"
      end        
      return "##{@ifc_id}"
    end
  end
end
