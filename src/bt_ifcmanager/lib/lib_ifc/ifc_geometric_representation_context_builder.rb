# frozen_string_literal: true

#  ifc_geometric_representation_context_builder.rb
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
    class IfcGeometricRepresentationContextBuilder
      attr_reader :ifc_geometric_representation_context

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder) if block_given?
        builder.ifc_geometric_representation_context
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @ifc_geometric_representation_context = @ifc_module::IfcGeometricRepresentationContext.new(ifc_model)
        set_coordinate_space_dimension('3')
        # set_precision(1.0e-5)
        set_default_world_coordinate_system
        set_default_true_north
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
        @ifc_geometric_representation_context.precision = IfcManager::Types::IfcReal.new(ifc_model, precision)
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

      def set_default_world_coordinate_system
        # Older Sketchup versions don't have Point2d
        if Geom.const_defined?(:Point2d)
          @ifc_geometric_representation_context.worldcoordinatesystem = @ifc_module::IfcAxis2Placement2D.new(@ifc_model)
          @ifc_geometric_representation_context.worldcoordinatesystem.location = @ifc_module::IfcCartesianPoint.new(
            @ifc_model, Geom::Point2d.new(0, 0)
          )
        else
          @ifc_geometric_representation_context.worldcoordinatesystem = @ifc_module::IfcAxis2Placement3D.new(@ifc_model)
          @ifc_geometric_representation_context.worldcoordinatesystem.location = @ifc_module::IfcCartesianPoint.new(
            @ifc_model, Geom::Point3d.new(0, 0, 0)
          )
        end
        self
      end

      def set_default_true_north
        # Older Sketchup versions don't have Vector2d
        if Geom.const_defined?(:Vector2d)
          @ifc_geometric_representation_context.truenorth = @ifc_module::IfcDirection.new(@ifc_model,
                                                                                          Geom::Vector2d.new(0, 1))
        else
          @ifc_geometric_representation_context.truenorth = @ifc_module::IfcDirection.new(@ifc_model,
                                                                                          Geom::Vector3d.new(0, 1, 0))
        end
        self
      end
    end
  end
end
