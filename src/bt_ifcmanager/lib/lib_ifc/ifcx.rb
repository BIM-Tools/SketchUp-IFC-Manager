# frozen_string_literal: true

#  ifcx.rb
#
#  Copyright 2023 Jan Brouwer <jan@brewsky.nl>
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

# mixin module to set the IfcX generation methods for all IFC classes

module BimTools
  module IfcX
    # Returns the IfcX representation for an object
    #
    # @return Hash
    def ifcx
      {
        type: self.class.name.split('::').last,
        id: @ifc_id,
        attributes: attributes.map { |attribute| [attribute, attribute_to_ifcx(attribute)] }.to_h
      }
    end

    # Returns the IfcX representation for an attribute
    #
    # @param property_name
    # @return Object
    def attribute_to_ifcx(property_name)
      property = send(property_name.downcase)
      property_to_ifcx(property)
    end

    def property_to_ifcx(property)
      case property
      when nil
        nil
      when Symbol # used for enumerations
        property.to_s
      when String, Numeric, TrueClass, FalseClass
        property
      when IfcManager::IfcGloballyUniqueId, IfcManager::Types::List, IfcManager::Types::Set, IfcManager::Types::BaseType
        property.ifcx
      else
        property.ref
      end
    end

    # Instead of the full IfcX object return a reference
    #   for example '#15'
    #
    # @return String
    def ref
      raise "Missing IFC object ID for: #{self}" unless @ifc_id

      "##{@ifc_id}"
    end
  end
end
