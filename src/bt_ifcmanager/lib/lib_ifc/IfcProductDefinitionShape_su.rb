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
      unless @representations && @representations.any?
        warn 'No representations defined for IfcProductDefinitionShape.'
        return nil
      end

      @representations.each_with_object({}) do |shape_representation, h|
        next unless shape_representation.respond_to?(:items)

        shape_representation.items.each do |item|
          h["#{shape_representation.representationidentifier.value} - #{item.globalid}"] = item.globalid
        end
      end
    end
  end
end
