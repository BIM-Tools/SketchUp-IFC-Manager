# frozen_string_literal: true

#  ifc_quantity_builder.rb
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
    class IfcQuantityBuilder
      attr_reader :ifc_quantity

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_quantity
      end

      def initialize(ifc_model)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
      end

      def set_name(name)
        @ifc_quantity.name = IfcManager::Types::IfcLabel.new(@ifc_model, name) if name
      end

      def set_value(value)
        case value
        when IfcManager::Types::IfcLengthMeasure
          @ifc_quantity = @ifc::IfcQuantityLength.new(@ifc_model)
          @ifc_quantity.lengthvalue = value
        when IfcManager::Types::IfcAreaMeasure
          @ifc_quantity = @ifc::IfcQuantityArea.new(@ifc_model)
          @ifc_quantity.areavalue = value
        when IfcManager::Types::IfcVolumeMeasure
          @ifc_quantity = @ifc::IfcQuantityVolume.new(@ifc_model)
          @ifc_quantity.volumevalue = value
        when IfcManager::Types::IfcMassMeasure
          @ifc_quantity = @ifc::IfcQuantityWeight.new(@ifc_model)
          @ifc_quantity.weightvalue = value
        end
      end

      def add_related_object(ifc_object)
        IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
          builder.set_relatingpropertydefinition(@ifc_property_set)
          builder.add_related_object(ifc_object)
        end
      end
    end
  end
end
