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
    def step()
      attribute_strings = properties().map { |attribute| attribute_to_step(attribute) }
      return "##{@ifc_id}=#{self.class.name.split('::').last.upcase}(#{attribute_strings.join(",")})"
    end

    def attribute_to_step(property_name)
      property = self.send(property_name.downcase)
      if property.nil?
        return "$"
      else
        if property.is_a? String
          return property
        elsif property.is_a?(IfcManager::IfcGloballyUniqueId) || property.is_a?(IfcManager::Ifc_List) || property.is_a?(IfcManager::Ifc_Set) || property.is_a?(IfcManager::Ifc_Type)
          return property.step
        elsif property.is_a? TrueClass
          return ".T."
        elsif property.is_a? FalseClass
          return ".F."
        else
          return property.ref
        end
      end
    end

    # Instead of the full step object return a reference
    def ref()
      return "##{@ifc_id}"
    end
  end
end
