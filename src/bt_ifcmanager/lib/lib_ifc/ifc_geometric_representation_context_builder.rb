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
        @su_model = ifc_model.su_model
        @ifc_geometric_representation_context = @ifc_module::IfcGeometricRepresentationContext.new(ifc_model)
        set_coordinate_space_dimension('3')
        # set_precision(1.0e-5)
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

      def set_world_coordinate_system(transformation = nil)
        if @ifc_geometric_representation_context.worldcoordinatesystem.nil?
          @ifc_geometric_representation_context.worldcoordinatesystem = @ifc_model.default_placement
        else
          @ifc_geometric_representation_context.worldcoordinatesystem = @ifc_module::IfcAxis2Placement3D.new(
            @ifc_model,
            transformation
          )
        end
        self
      end

      def set_true_north(direction)
        @ifc_geometric_representation_context.truenorth = direction
        self
      end

      # Sets the default TrueNorth direction for the IFC geometric representation context.
      # The default direction is (0, 1) in the xy-plane.
      # Uses Geom::Vector2d if available, otherwise falls back to Geom::Vector3d.
      #
      # @return [self] Returns the builder instance for method chaining.
      def set_default_true_north
        @ifc_geometric_representation_context.truenorth = create_direction(0, 1)
        self
      end

      # Sets TrueNorth based on an input angle in degrees.
      # Uses Geom::Vector2d if available, otherwise falls back to Geom::Vector3d.
      #
      # @param angle_degrees [Float] The angle in degrees where north is zero.
      # @return [self] Returns the builder instance for method chaining.
      def set_true_north_from_angle(angle_degrees)
        angle_radians = angle_degrees.radians
        x = Math.sin(angle_radians)
        y = Math.cos(angle_radians)
        @ifc_geometric_representation_context.truenorth = create_direction(x, y)
        self
      end

      # Retrieves the north angle from the SketchUp model and sets TrueNorth.
      # If the angle is nil, it sets the default True North direction.
      #
      # @return [self] Returns the builder instance for method chaining.
      def set_true_north_from_model
        north_angle = @su_model.shadow_info['NorthAngle']
        if north_angle.nil?
          set_default_true_north
        else
          set_true_north_from_angle(north_angle)
        end
        self
      end

      private

      # Creates a direction vector based on the provided x and y components.
      # Uses Geom::Vector2d if available, otherwise falls back to Geom::Vector3d.
      #
      # @param x [Float] The x component of the direction vector.
      # @param y [Float] The y component of the direction vector.
      # @return [IfcDirection] The created IfcDirection object.
      def create_direction(x, y)
        direction = if Geom.const_defined?(:Vector2d)
                      Geom::Vector2d.new(x, y)
                    else
                      Geom::Vector3d.new(x, y, 0)
                    end
        @ifc_module::IfcDirection.new(@ifc_model, direction)
      end
    end
  end
end
