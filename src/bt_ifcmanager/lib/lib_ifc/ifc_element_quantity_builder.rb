# frozen_string_literal: true

#  ifc_element_quantity_builder.rb
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
    class IfcElementQuantityBuilder
      attr_reader :ifc_element_quantity

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_element_quantity
      end

      def initialize(ifc_model)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_element_quantity = @ifc::IfcElementQuantity.new(ifc_model)
        @ifc_element_quantity.quantities = IfcManager::Types::Set.new
      end

      def set_name(name)
        @ifc_element_quantity.name = IfcManager::Types::IfcLabel.new(@ifc_model, name) if name
      end

      def add_related_object(ifc_object)
        IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
          builder.set_relatingpropertydefinition(@ifc_element_quantity)
          builder.add_related_object(ifc_object)
        end
      end

      def set_quantities(quantities)
        @ifc_element_quantity.quantities = IfcManager::Types::Set.new(quantities)
      end
    end
  end
end
