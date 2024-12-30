# frozen_string_literal: true

#  ifc_product_definition_shape_builder.rb
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
    class IfcProductDefinitionShapeBuilder
      attr_reader :ifc_product_definition_shape

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_product_definition_shape
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @ifc_product_definition_shape = @ifc_module::IfcProductDefinitionShape.new(ifc_model)
        @ifc_product_definition_shape.representations = Types::List.new
      end

      def add_representation(representation)
        @ifc_product_definition_shape.representations.add(representation)
      end

      # Add a product to the product definition shape
      # to set inverse relationship ShapeOfProduct
      def add_product(ifc_entity)
        @ifc_product_definition_shape.shapeofproduct = [ifc_entity]
      end

      # (!) this is not in the ifc schema
      def set_global_id(global_id)
        @ifc_product_definition_shape.globalid = global_id
      end
    end
  end
end
