# frozen_string_literal: true

#  ifc_geometric_representation_sub_context_builder.rb
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

require_relative 'ifc_geometric_representation_context_builder'

module BimTools
  module IfcManager
    class IfcGeometricRepresentationSubContextBuilder < IfcGeometricRepresentationContextBuilder
      UNSUPPORTED_VERSIONS = ['IFC2X3'].freeze

      def self.build(ifc_model)
        builder = new(ifc_model)
        return nil unless builder.supported_version?

        yield(builder) if block_given?
        builder.ifc_geometric_representation_context
      end

      def initialize(ifc_model)
        @ifc_model = ifc_model
        @ifc_module = ifc_model.ifc_module
        return unless supported_version?

        @ifc_geometric_representation_context = @ifc_module::IfcGeometricRepresentationSubContext.new(ifc_model)
        set_coordinate_space_dimension('*')
        set_precision('*')
        set_world_coordinate_system('*')
        set_true_north('*')
      end

      def set_context_identifier(identifier)
        @ifc_geometric_representation_context.contextidentifier = Types::IfcLabel.new(@ifc_model, identifier)
        self
      end

      def set_context_type(type)
        @ifc_geometric_representation_context.contexttype = Types::IfcLabel.new(@ifc_model, type)
        self
      end

      def set_coordinate_space_dimension(dimension)
        @ifc_geometric_representation_context.coordinatespacedimension = dimension
        self
      end

      def set_precision(precision)
        @ifc_geometric_representation_context.precision = precision
        self
      end

      def set_world_coordinate_system(system)
        @ifc_geometric_representation_context.worldcoordinatesystem = system
        self
      end

      def set_true_north(direction)
        @ifc_geometric_representation_context.truenorth = direction
        self
      end

      def set_parent_context(context)
        @ifc_geometric_representation_context.parentcontext = context
        self
      end

      def set_target_view(view)
        @ifc_geometric_representation_context.targetview = view.to_sym
        self
      end

      def supported_version?
        !UNSUPPORTED_VERSIONS.include?(@ifc_model.ifc_version)
      end
    end
  end
end
