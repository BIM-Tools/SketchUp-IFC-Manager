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
      
      line = String.new
      properties = properties()
      properties.each do |property_name|
        property = self.send(property_name.downcase)
        if property
          if property.is_a? String
            line << property
          elsif property.is_a?(IfcManager::Ifc_Set) || property.is_a?(IfcManager::Ifc_Type) || property.is_a?(IfcManager::IfcReal)
            line << property.step
          else
            line << "##{property.ifc_id.to_s}"
          end
        else
          line << "$"
        end
        
        #skip the , for the last element
        unless property_name == properties.last
          line << ", "
        end
      end
      return "##{@ifc_id.to_s} = #{self.class.name.split('::').last.upcase}(#{line})"
    end # step
 end # module Step
end # module BimTools
