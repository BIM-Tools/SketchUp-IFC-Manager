# frozen_string_literal: true

#  ifc_mapped_item_builder.rb
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

module BimTools
  module IfcManager
    class IfcMappedItemBuilder
      attr_reader :ifc_mapped_item

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.validate
        builder.ifc_mapped_item
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_mapped_item = @ifc::IfcMappedItem.new(ifc_model)
      end

      def validate
        # Set default mappingtarget when not set
        set_mappingtarget unless @ifc_mapped_item.mappingtarget
      end

      def set_mappingsource(source)
        @ifc_mapped_item.mappingsource = source
      end

      def set_mappingtarget(target = nil)
        unless target
          target = @ifc::IfcCartesianTransformationOperator3D.new(@ifc_model)
          target.localorigin = @ifc_model.default_location
        end
        @ifc_mapped_item.mappingtarget = target
      end

      def add_representation(representation)
        @ifc_mapped_item.representations.add(representation)
      end
    end
  end
end
