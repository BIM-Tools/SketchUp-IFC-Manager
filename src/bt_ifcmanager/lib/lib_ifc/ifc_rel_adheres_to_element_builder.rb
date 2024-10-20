# frozen_string_literal: true

#  ifc_rel_adheres_to_element_builder.rb
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

require_relative 'ifc_types'

module BimTools
  module IfcManager
    class IfcRelAdheresToElementBuilder
      UNSUPPORTED_VERSIONS = ['IFC 2x3', 'IFC 4'].freeze

      attr_reader :ifc_rel_adheres_to_element

      def self.build(ifc_model)
        builder = new(ifc_model)
        return nil unless builder.supported_version?

        yield(builder) if block_given?
        builder
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @ifc_rel_adheres_to_element = @ifc_module::IfcRelAdheresToElement.new(ifc_model)
        @ifc_rel_adheres_to_element.relatedsurfacefeatures = IfcManager::Types::Set.new
      end

      def set_relating_element(element)
        raise TypeError, 'Expected IfcElement' unless element.is_a?(@ifc_module::IfcElement)

        @ifc_rel_adheres_to_element.relatingelement = element
        self
      end

      def add_related_surface_feature(surface_feature)
        raise TypeError, 'Expected IfcSurfaceFeature' unless surface_feature.is_a?(@ifc_module::IfcSurfaceFeature)

        @ifc_rel_adheres_to_element.relatedsurfacefeatures.add(surface_feature)
        self
      end

      def supported_version?
        !UNSUPPORTED_VERSIONS.include?(@ifc_model.ifc_version)
      end
    end
  end
end
