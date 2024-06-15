# frozen_string_literal: true

#  ifc_property_builder.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'ifc_types'

module BimTools
  module IfcManager
    class IfcPropertyBuilder
      attr_reader :ifc_property

      def self.build(ifc_model, property_type = :single_value)
        builder = new(ifc_model, property_type)
        yield(builder)
        builder.ifc_property
      end

      def initialize(ifc_model, property_type)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @property_type = property_type

        case @property_type
        when :enumeration
          @ifc_property = @ifc_module::IfcPropertyEnumeratedValue.new(@ifc_model)
          @ifc_property.enumerationvalues = IfcManager::Types::List.new
        else # :single_value
          @ifc_property = @ifc_module::IfcPropertySingleValue.new(@ifc_model)
        end
      end

      def set_name(name)
        @ifc_property.name = IfcManager::Types::IfcLabel.new(@ifc_model, name) if name
      end

      def set_value(ifc_value)
        return unless ifc_value

        case @property_type
        when :enumeration
          @ifc_property.enumerationvalues.add(ifc_value)
        else # :single_value
          @ifc_property.nominalvalue = ifc_value
          @ifc_property.nominalvalue.long = true
        end
      end

      def set_enumeration_reference(options, property_enumeration_name = nil)
        return unless options

        property_name = @ifc_property.name
        ifc_options = options.map do |item|
          IfcManager::Types::IfcLabel.new(@ifc_model, item, true)
        end
        enumeration_values = IfcManager::Types::List.new(ifc_options)
        if @ifc_model.property_enumerations.key?(property_name.value) && (@ifc_model.property_enumerations[property_name.value].enumerationvalues.step == enumeration_values.step)
          property_enumeration = @ifc_model.property_enumerations[property_name.value]
        else
          property_enumeration = @ifc_module::IfcPropertyEnumeration.new(@ifc_model)
          property_enumeration.name = IfcManager::Types::IfcLabel.new(
            @ifc_model,
            property_enumeration_name || property_name
          )
          property_enumeration.enumerationvalues = enumeration_values
          @ifc_model.property_enumerations[property_name.value] = property_enumeration
        end
        @ifc_property.enumerationreference = property_enumeration
      end
    end
  end
end
