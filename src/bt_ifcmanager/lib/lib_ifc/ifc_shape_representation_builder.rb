# frozen_string_literal: true

#  ifc_shape_representation_builder.rb
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
    class IfcShapeRepresentationBuilder
      attr_reader :ifc_shape_representation

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_shape_representation
      end

      def initialize(ifc_model)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_shape_representation = @ifc::IfcShapeRepresentation.new(ifc_model)

        set_representationidentifier('Body')
        set_items
      end

      def set_contextofitems(representationcontext)
        @ifc_shape_representation.contextofitems = representationcontext
      end

      def set_representationidentifier(identifier = 'Body')
        @ifc_shape_representation.representationidentifier = Types::IfcLabel.new(@ifc_model, identifier)
      end

      def set_representationtype(type = nil)
        # Check if Mapped representation should be used
        # (?) && (sketchup.count_instances > 1) # (?) Always use mapped items? also for objects that are used only once?
        type ||= if @ifc_model.options[:mapped_items]
                   'MappedRepresentation'
                 else
                   'Brep'
                 end
        @ifc_shape_representation.representationtype = Types::IfcLabel.new(@ifc_model, type)
      end

      def set_items(items = [])
        @ifc_shape_representation.items = Types::Set.new(items)
      end

      def add_item(item)
        @ifc_shape_representation.items.add(item)
      end
    end
  end
end
