# frozen_string_literal: true

#  classifications.rb
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
  module IfcManager
    module GeometryHelpers
      # This module provides helper methods for working with geometry in SketchUp.

      ORIGIN = Geom::Point3d.new(0, 0, 0)
      Z_AXIS = Geom::Vector3d.new(0, 0, 1)

      class << self
        # Determines if a SketchUp component definition is an extrusion.
        #
        # @param definition [Sketchup::ComponentDefinition] The SketchUp component definition.
        # @return [Array] An array containing the bottom face and the direction vector.
        def is_extrusion?(definition)
          faces = definition.entities.grep(Sketchup::Face)
          face_groups = group_faces_by_normal(faces)
          extrudable_face_groups = extrudable_faces(face_groups)

          if extrudable_face_groups.length == 1
            select_bottom_face_and_direction(*extrudable_face_groups.first)
          else
            select_bottom_face_and_direction(*select_closest_group_to_z_axis(extrudable_face_groups))
          end
        end

        private

        # Returns the face in the group closest to the origin plane perpendicular to the given vector and the direction to the other face.
        #
        # @param vector [Geom::Vector3d] The vector used to determine the face extrusion direction.
        # @param group [Sketchup::Face] The group of faces.
        # @return [Array] An array containing the bottom face and the direction vector.
        def select_bottom_face_and_direction(vector, faces)
          bottom_face = faces.min_by { |face| face.bounds.center.distance_to_plane([ORIGIN, vector]) }
          direction = (faces - [bottom_face]).first.bounds.center - bottom_face.bounds.center
          [bottom_face, direction]
        end

        #
        # Returns the group with the normal vector closest to the Z-axis.
        #
        # @param face_groups [Array<Array>] The collection of face groups, where each group is represented by an array containing the normal vector and the faces.
        # @return [Array] The face group that is closest to the Z-axis, represented by an array containing the normal vector and the faces.
        def select_closest_group_to_z_axis(face_groups)
          face_groups.min_by do |normal, _faces|
            normal.angle_between(Z_AXIS)
          end
        end

        # Groups faces by parallel normals.
        #
        # @param faces [Array<Sketchup::Face>] The array of SketchUp faces.
        # @return [Hash<Vector3d, Array<Sketchup::Face>>] A hash where the keys are the parallel normal vectors and the values are arrays of faces.
        def group_faces_by_normal(faces)
          groups = Hash.new { |h, k| h[k] = [] }

          faces.each do |face|
            normal = face.normal
            key = groups.keys.find { |k| k.parallel?(normal) }
            key = normal if key.nil?
            groups[key] << face
          end

          groups
        end

        # Selects the face groups that are extrudable.
        #
        # A face group is considered extrudable if it meets the following conditions:
        # - It contains exactly 2 faces.
        # - The two faces have the same number of edges.
        # - The two faces have the same area, within the precision of floating point comparison.
        # - The two faces have the same bounding box diagonal, within the precision of floating point comparison.
        # - If there are any face groups where the number of edges is not 4, all groups where the number of edges is not 4 are returned.
        #
        # @param face_groups [Array<Array>] An array of face groups, where each group is represented by an array containing the normal vector and the faces.
        # @return [Array<Array>] An array of extrudable face groups.
        def extrudable_faces(face_groups)
          selected_groups = select_extrudable_groups(face_groups)
          not_four_edges, four_edges = partition_by_edge_count(selected_groups)
          extrudable_groups = not_four_edges.any? ? not_four_edges : four_edges

          extrudable_groups.delete_if do |normal, faces|
            vector_between_faces = faces[0].bounds.center.vector_to(faces[1].bounds.center)
            other_normals = extrudable_groups.keys - [normal]
            !other_normals.all? { |other_normal| vector_between_faces.perpendicular?(other_normal) }
          end

          # Create a new hash where the keys are the vector_between_faces and the values are the faces
          new_extrudable_groups = {}
          extrudable_groups.each do |_normal, faces|
            vector_between_faces = faces[0].bounds.center.vector_to(faces[1].bounds.center)
            new_extrudable_groups[vector_between_faces] = faces
          end

          new_extrudable_groups
        end

        def select_extrudable_groups(face_groups)
          face_groups.select do |_normal, faces|
            faces.length == 2 && same_edge_count?(faces) && same_area?(faces) && same_diagonal?(faces)
          end
        end

        def same_edge_count?(faces)
          faces[0].edges.length == faces[1].edges.length
        end

        def same_area?(faces)
          Length.new(faces[0].area) == Length.new(faces[1].area)
        end

        def same_diagonal?(faces)
          faces[0].bounds.diagonal == faces[1].bounds.diagonal
        end

        def partition_by_edge_count(groups)
          not_four_edges, four_edges = groups.partition { |_normal, faces| faces[0].edges.length != 4 }
          [not_four_edges.to_h, four_edges.to_h]
        end
      end
    end
  end
end
