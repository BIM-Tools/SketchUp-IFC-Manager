# frozen_string_literal: true

#  IfcBuildingElementProxy_su.rb
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
  module IfcBuildingElementProxy_su
    VALID_COMPOSITION_TYPES = %i[COMPLEX ELEMENT PARTIAL].freeze

    attr_reader :compositiontype

    def initialize(ifc_model, sketchup, _total_transformation)
      @ifc_version = ifc_model.ifc_version
      super
    end

    # CompositionType attribute deprecated in IFC4
    def compositiontype=(value)
      return unless @ifc_version == 'IFC 2x3'

      enum_value = if value.is_a?(String)
                     value.upcase.to_sym
                   elsif value.respond_to?(:value)
                     value.value.upcase.to_sym
                   else
                     value.to_sym
                   end

      @compositiontype = VALID_COMPOSITION_TYPES.include?(enum_value) ? enum_value : nil
    end
  end
end