# frozen_string_literal: true

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
    def step
      attribute_strings = attributes.map { |attribute| attribute_to_step(attribute) }
      "##{@ifc_id}=#{self.class.name.split('::').last.upcase}(#{attribute_strings.join(',')})"
    end

    # Returns the STEP representation for an attribute
    #
    # @param property_name
    # @return String
    def attribute_to_step(property_name)
      property = send(property_name.downcase)
      property_to_step(property)
    end

    def property_to_step(property)
      case property
      when nil
        '$'
      when Symbol # used for enumerations
        ".#{property.upcase}."
      when String
        property
      when TrueClass
        '.T.'
      when FalseClass
        '.F.'
      when IfcManager::IfcGloballyUniqueId, IfcManager::Types::List, IfcManager::Types::Set, IfcManager::Types::BaseType
        property.step
      when Integer
        property.to_s
      else
        property.ref
      end
    end

    # Instead of the full step object return a STEP reference
    #   for example '#15'
    #
    # @return String
    def ref
      raise "Missing IFC object ID for: #{self}" unless @ifc_id

      "##{@ifc_id}"
    end
  end
end
