# frozen_string_literal: true

#  ifc_extruded_area_solid_builder.rb
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
    class IfcExtrudedAreaSolidBuilder
      attr_reader :ifc_extruded_area_solid

      # Builder method for building new IfcExtrudedAreaSolid objects
      #
      # @param [IfcModel] ifc_model Model context for new IfcExtrudedAreaSolid
      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)

        # Validation/Correction steps
        # builder.set_sweptarea unless builder.ifc_extruded_area_solid.sweptarea
        # builder.set_extruded_direction unless builder.ifc_extruded_area_solid.extruded_direction
        # builder.set_depth unless builder.ifc_extruded_area_solid.depth

        builder.ifc_extruded_area_solid
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_extruded_area_solid = @ifc::IfcExtrudedAreaSolid.new(ifc_model)
      end

      def set_sweptarea_from_face(face, transformation)
        raise ArgumentError, 'Invalid face' if face.nil?
        raise ArgumentError, 'Invalid transformation' if transformation.nil?

        # Define the line as an array with the point and the direction
        line = [transformation.origin, face.normal]

        # Define the plane as an array with a point on the plane and the normal
        plane = [face.bounds.center, face.normal]

        # Find the intersection point between the line and the plane
        intersection_point = Geom.intersect_line_plane(line, plane)

        # Check if the face is parallel to the XY plane
        if face.normal.parallel?(transformation.zaxis)
          # Create a translation transformation that moves the face to the XY plane
          transformation_2d = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -face.bounds.center.z))
        # Check if the face is perpendicular to the XY plane
        elsif face.normal.perpendicular?(transformation.zaxis)
          # Create a rotation transformation that rotates the face to the XY plane
          transformation_2d = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(1, 0, 0),
                                                            90.degrees)
        else
          # Find two orthogonal vectors on the plane
          xaxis = face.normal.cross(Geom::Vector3d.new(1, 0, 0))
          yaxis = face.normal.cross(xaxis)

          # Create a 2D transformation that projects onto the plane of the face
          transformation_2d = Geom::Transformation.axes(intersection_point, xaxis, yaxis)
        end

        # Transform the original 3D transformation back to its original space
        transformation_3d = transformation_2d.inverse * transformation

        # Set the position of the extruded area solid
        set_position(transformation_3d)

        profile_def = nil
        outer_curve = create_ifc_polyline(face.outer_loop, transformation_2d)

        if face.loops.size > 1
          profile_def = @ifc::IfcArbitraryProfileDefWithVoids.new(@ifc_model)
          profile_def.innercurves = face.loops[1..-1].map { |loop| create_ifc_polyline(loop, transformation_2d) }
        else
          profile_def = @ifc::IfcArbitraryClosedProfileDef.new(@ifc_model)
        end

        profile_def.profiletype = :AREA
        profile_def.outercurve = outer_curve

        set_sweptarea(profile_def)
      end

      # Set IfcExtrudedAreaSolid swept area
      # The surface defining the area to be swept. It is given as a profile definition within the xy plane of the position coordinate system.
      # IfcProfileDef
      #
      # @param [Sketchup::Face] face
      # @param [Object] transformation
      def set_sweptarea(profile_def)
        raise ArgumentError, 'Invalid profile definition' unless profile_def.is_a?(@ifc::IfcArbitraryClosedProfileDef)

        @ifc_extruded_area_solid.sweptarea = profile_def
      end

      # Set IfcExtrudedAreaSolid position
      # Position coordinate system for the resulting swept solid of the sweeping operation. The position coordinate system allows for re-positioning of the swept solid. If not provided, the swept solid remains within the position as determined by the cross section or by the directrix used for the sweeping operation.
      # IfcAxis2Placement3D
      #
      # @param [Object] center
      def set_position(transformation)
        @ifc_extruded_area_solid.position = @ifc::IfcAxis2Placement3D.new(@ifc_model, transformation)
      end

      # Set IfcExtrudedAreaSolid extruded direction
      # The direction in which the surface, provided by SweptArea is to be swept.
      # IfcDirection
      #
      # @param [Geom::Vector3d] vector
      def set_extruded_direction(vector)
        @ifc_extruded_area_solid.extrudeddirection = @ifc::IfcDirection.new(@ifc_model, vector)
      end

      # Set IfcExtrudedAreaSolid depth
      # The distance the surface is to be swept along the ExtrudedDirection.
      # IfcPositiveLengthMeasure
      #
      # @param [Object] length
      def set_depth(depth)
        @ifc_extruded_area_solid.depth = IfcManager::Types::IfcPositiveLengthMeasure.new(@ifc_model, depth)
      end

      private

      def create_ifc_polyline(loop, transformation)
        points = loop.vertices.map do |vertex|
          position = Geom::Point2d.new(vertex.position.transform(transformation).x,
                                       vertex.position.transform(transformation).y)
          @ifc::IfcCartesianPoint.new(@ifc_model, position)
        end
        polyline = @ifc::IfcPolyline.new(@ifc_model)
        polyline.points = IfcManager::Types::List.new(points)
        polyline
      end
    end
  end
end
