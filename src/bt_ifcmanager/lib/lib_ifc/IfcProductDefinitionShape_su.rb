# frozen_string_literal: true

#  IfcProductDefinitionShape_su.rb
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
  module IfcProductDefinitionShape_su
    attr_accessor :shapeofproduct, :globalid

    def initialize(ifc_model)
      super
      @ifc_module = ifc_model.ifc_module
    end

    def ifcx
      product = @shapeofproduct[0] if @shapeofproduct && @shapeofproduct.length > 0
      return unless product

      @representations.flat_map do |representation|
        representation.items.select { |item| item.is_a?(@ifc_module::IfcTriangulatedFaceSet) }.map do |item|
          global_id = item.globalid.ifcx
          {
            'def' => 'def',
            'type' => 'UsdGeom:Mesh',
            'comment' => "product definition shape: #{product.name.value}",
            'name' => "#{global_id}_Body",
            'inherits' => ["</#{global_id}>"]
          }
        end
      end
    end
  end
end
