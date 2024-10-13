# frozen_string_literal: true

#  IfcStyledItem_su.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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
  module IfcStyledItem_su
    def initialize(ifc_model, brep)
      super
      @ifc_module = ifc_model.ifc_module
      instance_variable_set(:@attr, ([:Item] + attributes))

      # Workaround for bug in IFC XSD's forward from IFC4, missing "item" attribute
      unless attributes.include? :Item
        @item = nil
        define_singleton_method(:attributes) do
          attributes = self.class.attributes
          return [:Item] + attributes
          return attributes
        end
        define_singleton_method(:item) do
          return @item
        end
        define_singleton_method(:item=) do |item|
          return @item = item
        end
      end

      @item = brep
    end
  end
end
