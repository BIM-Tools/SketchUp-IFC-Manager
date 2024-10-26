# frozen_string_literal: true

#  IfcGeometricRepresentationSubContext_su.rb
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
  module IfcGeometricRepresentationSubContext_su
    def initialize(ifc_model)
      super
      instance_variable_set(:@attr, ([:ParentContext] + attributes))

      # Workaround for bug in IFC XSD's forward from IFC4X3, missing "parentcontext" attribute
      return if attributes.include? :ParentContext

      @parentcontext = nil
      define_singleton_method(:attributes) do
        attributes = self.class.attributes
        attributes.insert(6, :ParentContext)
      end
      define_singleton_method(:parentcontext) do
        @parentcontext
      end
      define_singleton_method(:parentcontext=) do |parentcontext|
        @parentcontext = parentcontext
      end
    end
  end
end
