# frozen_string_literal: true

#  ifc_property_set_builder.rb
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
require_relative 'ifc_rel_defines_by_properties_builder'

module BimTools
  module IfcManager
    class IfcPropertySetBuilder
      attr_reader :ifc_property_set

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_property_set
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @ifc_property_set = @ifc_module::IfcPropertySet.new(ifc_model)
        @ifc_property_set.hasproperties = IfcManager::Types::Set.new
      end

      def set_name(name)
        @ifc_property_set.name = IfcManager::Types::IfcLabel.new(@ifc_model, name)

        # @todo before adding persistent GlobalId prevent duplicate IfcPropertySet definitions
        # @ifc_property_set.globalid = IfcManager::IfcGloballyUniqueId.new(@ifc_model, "IfcPropertySet.#{name}")
      end

      def add_related_object(ifc_object)
        IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
          builder.set_relatingpropertydefinition(@ifc_property_set)
          builder.add_related_object(ifc_object)
        end
      end

      def set_properties(properties)
        @ifc_property_set.hasproperties = IfcManager::Types::Set.new(properties)
      end
    end
  end
end
