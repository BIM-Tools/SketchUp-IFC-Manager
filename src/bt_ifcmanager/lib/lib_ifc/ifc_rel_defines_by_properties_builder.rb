# frozen_string_literal: true

#  ifc_rel_defines_by_properties_builder.rb
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
    class IfcRelDefinesByPropertiesBuilder
      attr_reader :ifc_rel_defines_by_properties

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_rel_defines_by_properties
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_rel_defines_by_properties = @ifc::IfcRelDefinesByProperties.new(ifc_model)
        @ifc_rel_defines_by_properties.relatedobjects = Types::Set.new
      end

      def set_relatingpropertydefinition(propertyset)
        @ifc_rel_defines_by_properties.relatingpropertydefinition = propertyset
      end

      def add_related_object(related_object)
        @ifc_rel_defines_by_properties.relatedobjects.add(related_object)
      end
    end
  end
end
