# frozen_string_literal: true

#  IfcRelDefinesByProperties_su.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcRelDefinesByProperties_su
    include BimTools::IfcX
    def initialize(ifc_model)
      @relatedobjects = nil
      super
      @ifc_module = ifc_model.ifc_module
    end

    def self.required_attributes(ifc_version)
      # (?) Add RelatingPropertyDefinition here?

      # In IFC2X3, the attribute 'RelatedObjects' is part of its parent class 'IfcRelDefines'.
      return [] if ifc_version == 'IFC 2x3'

      [:RelatedObjects]
    end

    def ifcx
      return [] unless @relatedobjects && @relatingpropertydefinition

      case @relatingpropertydefinition
      when @ifc_module::IfcPropertySet
        properties = @relatingpropertydefinition.hasproperties
      when @ifc_module::IfcElementQuantity
        properties = @relatingpropertydefinition.quantities
      else
        puts "Unsupported RelatingPropertyDefinition type: #{@relatingpropertydefinition.class}"
        return []
      end

      # Apply properties to each related object
      results = []
      @relatedobjects.each do |relatedobject|
        begin
          properties.each do |property|
            next unless property.respond_to?(:name) && property.name && property.name.respond_to?(:value)

            results << {
              path: relatedobject.globalid.ifcx,
              attributes: {
                "bsi::ifc::prop::#{property.name.value}": property_to_ifcx(property)
              }
            }
          end
        rescue StandardError => e
          puts "  Error processing object: #{e.message}"
        end
      end

      results
    end
  end
end
