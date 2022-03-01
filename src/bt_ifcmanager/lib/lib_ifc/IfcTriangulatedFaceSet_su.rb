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

module BimTools
  module IfcTriangulatedFaceSet_su
    def initialize(ifc_model, faces, transformation, su_materials, parent_material)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module
      su_front_material = su_materials[0] || parent_material
      su_back_material = su_materials[1] || parent_material

      # vertex_count = faces.flat_map{|face| [face.vertices]}.to_set.length
      # polygonmesh = Geom::PolygonMesh.new(vertex_count,faces.length)

      # (!)loop twice?
      meshes = faces.map { |face| face.mesh(7) }
      faces.map { |face| ifc_model.textures.load(face, true) }

      points = []
      uv_coordinates_front = []
      uv_coordinates_back = []
      normals_front = []
      normals_back = []
      polygons = []
      point_total = 0
      face_mesh_id = 0
      @closed = false
      @coordindex = BimTools::IfcManager::Ifc_List.new # polygons as indexes
      while face_mesh_id < meshes.length
        face_mesh = meshes[face_mesh_id]
        face_mesh.transform! transformation
        mesh_point_id = 1
        while mesh_point_id <= face_mesh.count_points
          index = mesh_point_id + point_total - 1
          points[index] = face_mesh.point_at(mesh_point_id)
          if su_front_material && su_front_material.texture
            uv_coordinates_front[index] = get_uv(face_mesh.uv_at(mesh_point_id, true))
            normals_front[index] = face_mesh.normal_at(mesh_point_id)
          end
          if su_back_material && su_back_material.texture
            uv_coordinates_back[index] = get_uv(face_mesh.uv_at(mesh_point_id, false))
            normals_back[index] = face_mesh.normal_at(mesh_point_id)
          end
          mesh_point_id += 1
        end

        face_mesh.polygons.each do |polygon|
          @coordindex.add(BimTools::IfcManager::Ifc_List.new(get_ifc_polygon(point_total, polygon)))
        end
        face_mesh_id += 1
        point_total += face_mesh.count_points
      end

      @coordinates = @ifc::IfcCartesianPointList3D.new(ifc_model)
      @coordinates.coordlist = BimTools::IfcManager::Ifc_List.new(points.map do |point|
        BimTools::IfcManager::Ifc_List.new(point.to_a.map  do |coord|
          BimTools::IfcManager::IfcLengthMeasure.new(ifc_model, coord)
        end)
      end)
      if ifc_model.textures
        styled_item = @ifc::IfcStyledItem.new(ifc_model, self)
        styled_item.styles = BimTools::IfcManager::Ifc_List.new()
        if su_front_material && su_texture = su_front_material.texture

          # check if material exists
          unless ifc_model.materials.key?(su_front_material)
            ifc_model.materials[su_front_material] = BimTools::IfcManager::MaterialAndStyling.new(ifc_model, su_front_material)
          end
          image_texture = ifc_model.materials[su_front_material].image_texture
          if image_texture
            surface_style = @ifc::IfcSurfaceStyle.new(ifc_model)
            surface_style.side = :positive
            texture_style = @ifc::IfcSurfaceStyleWithTextures.new(ifc_model)
            texture_map = @ifc::IfcIndexedTriangleTextureMap.new(ifc_model)
            texture_map.mappedto = self
            texture_map.maps = BimTools::IfcManager::Ifc_List.new([image_texture])

            tex_vert_list = @ifc::IfcTextureVertexList.new(ifc_model)
            tex_vert_list.texcoordslist = BimTools::IfcManager::Ifc_Set.new(uv_coordinates_front)

            texture_map.texcoords = tex_vert_list
            texture_style.textures = BimTools::IfcManager::Ifc_List.new([image_texture])
            surface_style.styles = BimTools::IfcManager::Ifc_Set.new([texture_style])
            styled_item.styles.add(surface_style)
          end
        end
        # if su_back_material && su_texture = su_back_material.texture

        #   # check if material exists
        #   unless ifc_model.materials.key?(su_back_material)
        #     ifc_model.materials[su_back_material] = BimTools::IfcManager::MaterialAndStyling.new(ifc_model, su_back_material)
        #   end
        #   image_texture = ifc_model.materials[su_back_material].image_texture
        #   if image_texture
        #     surface_style = @ifc::IfcSurfaceStyle.new(ifc_model)
        #     surface_style.side = :negative
        #     texture_style = @ifc::IfcSurfaceStyleWithTextures.new(ifc_model)
        #     texture_map = @ifc::IfcIndexedTriangleTextureMap.new(ifc_model)
        #     texture_map.mappedto = self
        #     texture_map.maps = BimTools::IfcManager::Ifc_List.new([image_texture])

        #     tex_vert_list = @ifc::IfcTextureVertexList.new(ifc_model)
        #     tex_vert_list.texcoordslist = BimTools::IfcManager::Ifc_Set.new(uv_coordinates_back)

        #     texture_map.texcoords = tex_vert_list
        #     texture_style.textures = BimTools::IfcManager::Ifc_List.new([image_texture])
        #     surface_style.styles = BimTools::IfcManager::Ifc_Set.new([texture_style])
        #     styled_item.styles.add(surface_style)
        #   end
        # end
      end
    end

    def get_ifc_polygon(point_total, polygon)
      polygon.map { |pt_id| BimTools::IfcManager::IfcInteger.new(@ifc_model, point_total + pt_id.abs) }
    end

    def get_uv(uvq)
      u = BimTools::IfcManager::IfcParameterValue.new(@ifc_model, uvq.x / uvq.z)
      v = BimTools::IfcManager::IfcParameterValue.new(@ifc_model, uvq.y / uvq.z)
      BimTools::IfcManager::Ifc_List.new([u, v])
    end
  end
end
