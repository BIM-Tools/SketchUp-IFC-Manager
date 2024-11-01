# frozen_string_literal: true

#  IfcCoordinateOperation_su.rb
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
  module IfcCoordinateOperation_su
    def initialize(ifc_model, _sketchup)
      super

      # Workaround for missing "SourceCRS" attribute in XSD schema for IFC4 and IFC4X3
      return if ifc_model.ifc_version == 'IFC 2x3'

      instance_variable_set(:@attr, ([:SourceCRS] + attributes))

      return if attributes.include? :SourceCRS

      @sourcecrs = nil
      define_singleton_method(:attributes) do
        attributes = self.class.attributes
        attributes.insert(0, :SourceCRS)
      end
      define_singleton_method(:sourcecrs) do
        @sourcecrs
      end
      define_singleton_method(:sourcecrs=) do |sourcecrs|
        @sourcecrs = sourcecrs
      end
    end
  end
end
