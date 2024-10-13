# frozen_string_literal: true

#  base_quantity_builder.rb
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

require_relative 'ifc_element_quantity_builder'
require_relative 'ifc_quantity_builder'


# Sketchup width = x
# Sketchup height = y
# Sketchup depth = z

module BimTools
  module IfcManager
    class BaseQuantityBuilder
      attr_reader :ifc_element_quantity

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_element_quantity
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
      end

      def add_base_quantities(ifc_product, su_object)
        case ifc_product
        when @ifc_module::IfcColumn
          calculate_and_add_base_quantities(ifc_product, su_object, ifc_product.total_transformation, 'Column', :depth, :max)
        when @ifc_module::IfcBeam
          calculate_and_add_base_quantities(ifc_product, su_object, ifc_product.total_transformation, 'Beam', :depth, :max)
        when @ifc_module::IfcSlab
          calculate_and_add_base_quantities(ifc_product, su_object, ifc_product.total_transformation, 'Slab', :depth, :min)
        when @ifc_module::IfcWall
          calculate_and_add_base_quantities(ifc_product, su_object, ifc_product.total_transformation, 'Wall', :height, :min)
        end
      end

      private

      def calculate_and_add_base_quantities(ifc_product, su_object, transformation, type, length_direction,
                                            comparison_method)
        volume = su_object.volume
        return unless volume > 0


        bounding_box = su_object.definition.bounds
        len_x = bounding_box.width
        len_y = bounding_box.height
        len_z = bounding_box.depth
        return unless transformation

        len_x = transformation.xscale * len_x
        len_y = transformation.yscale * len_y
        len_z = transformation.zscale * len_z

        instance_transformation = transformation * su_object.transformation.inverse
        volume = volume * instance_transformation.xscale * instance_transformation.yscale * instance_transformation.zscale

        dimensions = { width: len_x, height: len_y, depth: len_z }
        length = dimensions[length_direction]

        volume_in_cubic_meters = volume * 0.000016387064

        quantities = []

        quantities << IfcQuantityBuilder.build(@ifc_model) do |builder|
          builder.set_value(IfcManager::Types::IfcVolumeMeasure.new(@ifc_model, volume_in_cubic_meters))
          builder.set_name('NetVolume')
        end

        if valid_cross_section?(dimensions, length_direction, length, comparison_method)
          cross_section_area = volume / length
          cross_section_area_in_square_meters = cross_section_area * 0.00064516

          length_name = 'Length'
          length_name = 'Depth' if type == 'Slab'
          length_name = 'Width' if type == 'Wall'

          quantities << IfcQuantityBuilder.build(@ifc_model) do |builder|
            builder.set_value(IfcManager::Types::IfcLengthMeasure.new(@ifc_model, length))
            builder.set_name(length_name)
          end

          if type == 'Wall'
            quantities << IfcQuantityBuilder.build(@ifc_model) do |builder|
              builder.set_value(IfcManager::Types::IfcLengthMeasure.new(@ifc_model, len_x))
              builder.set_name('Length')
            end
          end

          area_name = 'CrossSectionArea'
          area_name = 'NetArea' if type == 'Slab'
          area_name = 'NetSideArea' if type == 'Wall'

          quantities << IfcQuantityBuilder.build(@ifc_model) do |builder|
            builder.set_value(IfcManager::Types::IfcAreaMeasure.new(@ifc_model, cross_section_area_in_square_meters))
            builder.set_name(area_name)
          end
        end

        elementquantity = IfcElementQuantityBuilder.build(@ifc_model) do |builder|
          builder.set_name("Qto_#{type}BaseQuantities")
          builder.set_quantities(quantities)
        end


        IfcRelDefinesByPropertiesBuilder.build(@ifc_model) do |builder|
          builder.set_relatingpropertydefinition(elementquantity)
          builder.add_related_object(ifc_product)
        end
      end

      def valid_cross_section?(dimensions, length_direction, length, comparison_method)
        dimensions.delete(length_direction)
        remaining_dimensions = dimensions.values
        if comparison_method == :max
          length >= remaining_dimensions.max
        elsif comparison_method == :min
          length <= remaining_dimensions.min
        end
      end
    end
  end
end
