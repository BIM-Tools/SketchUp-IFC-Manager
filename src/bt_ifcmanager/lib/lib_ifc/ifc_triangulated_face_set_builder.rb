# frozen_string_literal: true

#  ifc_triangulated_face_set_builder.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'material_and_styling'

module BimTools
  module IfcManager
    class IfcTriangulatedFaceSetBuilder
      attr_reader :ifc_triangulated_face_set

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)

        builder.ifc_triangulated_face_set.coordinates ||= IfcManager::Types::List.new
        builder.ifc_triangulated_face_set.coordindex ||= IfcManager::Types::List.new

        builder.ifc_triangulated_face_set
      end

      def initialize(ifc_model)
        @ifc = Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_triangulated_face_set = @ifc::IfcTriangulatedFaceSet.new(ifc_model)
        @ifc_triangulated_face_set.coordinates = @ifc::IfcCartesianPointList3D.new(ifc_model)

        # # @todo closed should be true for manifold geometry
        # @closed = false
        @coordindex = IfcManager::Types::List.new
      end

      def set_faces(
        faces,
        transformation,
        parent_material,
        front_material = nil,
        back_material = nil,
        double_sided_faces = false
      )
        ifc_model = @ifc_model
        points = []
        uv_coordinates_front = []
        uv_coordinates_back = []
        normals_front = []
        normals_back = []
        point_total = 0

        add_parent_texture = faces.any? { |face| face.material.nil? }
        add_material_to_model(parent_material) if add_parent_texture

        meshes = faces.map { |face| [face.mesh(7), get_face_transformation(face).inverse] }

        meshes.each do |mesh|
          face_mesh, face_transformation = mesh
          front_texture = texture_exists?(front_material)
          back_texture = texture_exists?(back_material) if double_sided_faces
          parent_texture = texture_exists?(parent_material)

          # Calculate UV transformation for parent texture if no texture is applied to the face
          if !(front_texture || back_texture) && parent_texture
            uv_transformation = calculate_uv_transformation(transformation, face_transformation,
                                                            parent_material.texture)
          end

          face_mesh.transform! transformation

          point_total = process_faces(face_mesh, point_total, points, uv_coordinates_front, uv_coordinates_back,
                                      normals_front, normals_back, front_texture, back_texture, parent_texture, uv_transformation, double_sided_faces)
        end

        @ifc_triangulated_face_set.coordinates.coordlist = IfcManager::Types::List.new(points.map do |point|
          IfcManager::Types::List.new(point.to_a.map do |coord|
            IfcManager::Types::IfcLengthMeasure.new(ifc_model, coord)
          end)
        end)

        @ifc_triangulated_face_set.closed = @closed
        @ifc_triangulated_face_set.normals = IfcManager::Types::List.new(normals_front.map do |normal|
          IfcManager::Types::List.new(normal.to_a.map do |coord|
            IfcManager::Types::IfcParameterValue.new(ifc_model, coord)
          end)
        end)
        @ifc_triangulated_face_set.coordindex = @coordindex

        return unless ifc_model.textures && (front_texture || back_texture || parent_texture)

        process_texture_maps(ifc_model, front_material, back_material, parent_material, uv_coordinates_front,
                             uv_coordinates_back, double_sided_faces)
      end

      private

      def create_texture_map(ifc_model, su_material, uv_coordinates)
        return unless su_material

        unless ifc_model.materials[su_material]
          ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(ifc_model, su_material)
        end
        image_texture = ifc_model.materials[su_material].image_texture
        return unless image_texture

        tex_vert_list = @ifc::IfcTextureVertexList.new(ifc_model)
        tex_vert_list.texcoordslist = IfcManager::Types::Set.new(uv_coordinates)
        texture_map = @ifc::IfcIndexedTriangleTextureMap.new(ifc_model)
        texture_map.mappedto = @ifc_triangulated_face_set
        texture_map.maps = IfcManager::Types::List.new([image_texture])
        texture_map.texcoords = tex_vert_list
        nil
      end

      def get_ifc_polygon(point_total, polygon)
        polygon.map { |pt_id| IfcManager::Types::IfcInteger.new(@ifc_model, point_total + pt_id.abs) }
      end

      def get_uv(uvq)
        IfcManager::Types::List.new(
          [IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.x / uvq.z),
           IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.y / uvq.z)]
        )
      end

      def get_uv_global(vertex, uv_transformation)
        uv_point = vertex.transform(uv_transformation)
        IfcManager::Types::List.new(
          [IfcManager::Types::IfcParameterValue.new(@ifc_model, uv_point.x),
           IfcManager::Types::IfcParameterValue.new(@ifc_model, uv_point.y)]
        )
      end

      def get_texture_transformation(texture)
        Geom::Transformation.scaling(1 / texture.width, 1 / texture.height, 1 / texture.height)
      end

      def get_face_transformation(face)
        plane_point = face.vertices[0].position
        normal = face.normal
        axes = normal.axes
        plane = [plane_point, normal]
        projected_origin = ORIGIN.project_to_plane(plane)
        Geom::Transformation.axes(projected_origin, axes[0], axes[1], axes[2])
      end

      def process_faces(face_mesh, point_total, points, uv_coordinates_front, uv_coordinates_back, normals_front,
                        normals_back, front_texture, back_texture, parent_texture, uv_transformation, double_sided_faces)
        (1..face_mesh.count_points).each do |mesh_point_id|
          index = mesh_point_id + point_total - 1
          points[index] = face_mesh.point_at(mesh_point_id)
          normals_front[index] = face_mesh.normal_at(mesh_point_id)
          normals_back[index] = face_mesh.normal_at(mesh_point_id) if double_sided_faces
          if front_texture || back_texture || parent_texture
            process_textures(front_texture, back_texture, parent_texture, face_mesh, mesh_point_id, points,
                             uv_coordinates_front, uv_coordinates_back, uv_transformation, double_sided_faces, index)
          end
        end

        face_mesh.polygons.each do |polygon|
          @coordindex.add(IfcManager::Types::List.new(get_ifc_polygon(point_total, polygon)))
        end

        point_total += face_mesh.count_points
        point_total
      end

      def process_textures(front_texture, back_texture, parent_texture, face_mesh, mesh_point_id, points,
                           uv_coordinates_front, uv_coordinates_back, uv_transformation, double_sided_faces, index)
        if front_texture
          uv_coordinates_front[index] = get_uv(face_mesh.uv_at(mesh_point_id, true))
        elsif parent_texture
          uv_coordinates_front[index] = get_uv_global(points[index], uv_transformation)
        end

        return unless double_sided_faces

        if back_texture
          uv_coordinates_back[index] = get_uv(face_mesh.uv_at(mesh_point_id, false))
        elsif parent_texture
          uv_coordinates_back[index] = get_uv_global(points[index], uv_transformation)
        end
      end

      def process_texture_maps(ifc_model, front_material, back_material, parent_material, uv_coordinates_front,
                               uv_coordinates_back, double_sided_faces)
        if front_material
          create_texture_map(ifc_model, front_material, uv_coordinates_front) if front_material.texture
        elsif parent_material && parent_material.texture
          create_texture_map(ifc_model, parent_material, uv_coordinates_front)
        end
        return unless double_sided_faces

        if back_material
          create_texture_map(ifc_model, back_material, uv_coordinates_back) if back_material.texture
        elsif parent_material && parent_material.texture
          create_texture_map(ifc_model, parent_material, uv_coordinates_back)
        end
      end

      def add_material_to_model(parent_material)
        return if @ifc_model.materials.key?(parent_material)

        @ifc_model.materials[parent_material] = IfcManager::MaterialAndStyling.new(@ifc_model, parent_material)
      end

      def texture_exists?(material)
        material && material.texture ? true : false
      end

      def calculate_uv_transformation(transformation, face_transformation, texture)
        texture_transformation = get_texture_transformation(texture)
        transformation.inverse * face_transformation * texture_transformation
      end
    end
  end
end
