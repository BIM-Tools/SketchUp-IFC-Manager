#  IfcTriangulatedFaceSet_su.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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
  module IfcTriangulatedFaceSet_su
    def initialize(ifc_model, faces, transformation, parent_material, front_material=nil, back_material=nil)
      super
      @ifc = IfcManager::Settings.ifc_module

      meshes = faces.map { |face|
        ifc_model.textures.load(face, true) if ifc_model.textures
        face.mesh(7)
      }

      points = []
      uv_coordinates_front = []
      uv_coordinates_back = []
      normals_front = []
      normals_back = []
      polygons = []
      point_total = 0
      face_mesh_id = 0

      # @todo closed should be true for manifold geometry
      @closed = false
      @coordindex = IfcManager::Types::List.new # polygons as indexes
      while face_mesh_id < meshes.length
        face_mesh = meshes[face_mesh_id]
        face_mesh.transform! transformation
        mesh_point_id = 1
        while mesh_point_id <= face_mesh.count_points
          index = mesh_point_id + point_total - 1
          points[index] = face_mesh.point_at(mesh_point_id)
          if front_material
            if front_material.texture
              uv_coordinates_front[index] = get_uv(face_mesh.uv_at(mesh_point_id, true))
              normals_front[index] = face_mesh.normal_at(mesh_point_id)
            end
          else
            if parent_material && parent_material.texture
              uv_coordinates_front[index] = get_uv(face_mesh.uv_at(mesh_point_id, true), parent_material.texture)
              normals_front[index] = face_mesh.normal_at(mesh_point_id)
            end
          end

          # @todo Catch the back material with a setting switch
          if back_material
            if back_material.texture
              uv_coordinates_back[index] = get_uv(face_mesh.uv_at(mesh_point_id, false))
              normals_back[index] = face_mesh.normal_at(mesh_point_id)
            end
          else
            if parent_material && parent_material.texture
              uv_coordinates_back[index] = get_uv(face_mesh.uv_at(mesh_point_id, false), parent_material.texture)
              normals_back[index] = face_mesh.normal_at(mesh_point_id)
            end
          end
          mesh_point_id += 1
        end

        face_mesh.polygons.each do |polygon|
          @coordindex.add(IfcManager::Types::List.new(get_ifc_polygon(point_total, polygon)))
        end
        face_mesh_id += 1
        point_total += face_mesh.count_points
      end

      @coordinates = @ifc::IfcCartesianPointList3D.new(ifc_model)
      @coordinates.coordlist = IfcManager::Types::List.new(points.map do |point|
        IfcManager::Types::List.new(point.to_a.map  do |coord|
          IfcManager::Types::IfcLengthMeasure.new(ifc_model, coord)
        end)
      end)

      if ifc_model.textures
        if front_material
          if front_material.texture
            create_texture_map(ifc_model, front_material, uv_coordinates_front)
          end
        elsif parent_material && parent_material.texture
          create_texture_map(ifc_model, parent_material, uv_coordinates_front)
        end
        if back_material
          if back_material.texture
            create_texture_map(ifc_model, back_material, uv_coordinates_back)
          end
        elsif parent_material && parent_material.texture
          create_texture_map(ifc_model, parent_material, uv_coordinates_back)
        end
      end
    end

    def create_texture_map(ifc_model, su_material, uv_coordinates)
      if su_material
        unless ifc_model.materials[su_material]
          ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(ifc_model, su_material)
        end
        image_texture = ifc_model.materials[su_material].image_texture
        if image_texture
          tex_vert_list = @ifc::IfcTextureVertexList.new(ifc_model)
          tex_vert_list.texcoordslist = IfcManager::Types::Set.new(uv_coordinates)
          texture_map = @ifc::IfcIndexedTriangleTextureMap.new(ifc_model)
          texture_map.mappedto = self
          texture_map.maps = IfcManager::Types::List.new([image_texture])
          texture_map.texcoords = tex_vert_list
        end
      end
    end

    def get_ifc_polygon(point_total, polygon)
      polygon.map { |pt_id| IfcManager::Types::IfcInteger.new(@ifc_model, point_total + pt_id.abs) }
    end

    def get_uv(uvq, texture=nil)
      if texture
        u = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.x / uvq.z*(1/texture.width))
        v = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.y / uvq.z*(1/texture.height))
      else
        u = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.x / uvq.z)
        v = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.y / uvq.z)
      end
      IfcManager::Types::List.new([u, v])
    end
  end
end
