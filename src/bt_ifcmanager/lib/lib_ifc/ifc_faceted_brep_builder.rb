# frozen_string_literal: true

#  ifc_faceted_brep_builder.rb
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

module BimTools
  module IfcFacetedBrep_su
    def initialize(ifc_model, su_faces, su_transformation)
      super
      @ifc = IfcManager::Settings.ifc_module
      ifcclosedshell = @ifc::IfcClosedShell.new(ifc_model, su_faces)
      @ifc_model = ifc_model
      @su_transformation = su_transformation
      @outer = ifcclosedshell
      @vertices = {}

      # multiply all transformation values to see if the component is flipped
      @flipped = !(@su_transformation.xaxis * @su_transformation.yaxis % @su_transformation.zaxis < 0)

      faces = su_faces.map { |face| add_face(face) }
      ifcclosedshell.cfsfaces = IfcManager::Types::Set.new(faces) if faces.length != 0
    end

    def add_face(su_face)
      create_points(su_face)
      ifc_face = @ifc::IfcFace.new(@ifc_model)
      texture_map = nil
      su_material = su_face.material

      if @ifc_model.textures && su_material && su_material.texture

        # check if material exists
        unless @ifc_model.materials.key?(su_material)
          @ifc_model.materials[su_material] = BimTools::IfcManager::MaterialAndStyling.new(@ifc_model, su_material)
        end
        image_texture = @ifc_model.materials[su_material].image_texture
        if image_texture
          texture_map = @ifc::IfcTextureMap.new(@ifc_model)
          uv_helper = su_face.get_UVHelper(true, true, @ifc_model.textures)
          @ifc_model.textures.load(su_face, true)
          texture_map.maps = IfcManager::Types::List.new([image_texture])
          texture_map.mappedto = ifc_face
        end
      end
      bounds = su_face.loops.map { |loop| create_loop(loop, texture_map, uv_helper) }
      ifc_face.bounds = IfcManager::Types::Set.new(bounds)
      ifc_face
    end

    def create_loop(loop, tex_map = nil, uv_helper = nil)
      # differenciate between inner and outer loops/bounds
      bound = if loop.outer?
                @ifc::IfcFaceOuterBound.new(@ifc_model)
              else
                @ifc::IfcFaceBound.new(@ifc_model)
              end

      points = loop.vertices.map { |vert| @vertices[vert] }
      polyloop = @ifc::IfcPolyLoop.new(@ifc_model)
      bound.bound = polyloop
      bound.orientation = @flipped
      polyloop.polygon = IfcManager::Types::List.new(points)
      tex_map.vertices = IfcManager::Types::Set.new(loop.vertices.map { |vert| get_uv(vert, uv_helper) }) if tex_map
      bound
    end

    def get_uv(vertex, uv_helper)
      uvq = uv_helper.get_front_UVQ(vertex.position)
      u = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.x / uvq.z)
      v = IfcManager::Types::IfcParameterValue.new(@ifc_model, uvq.y / uvq.z)
      texture_vert = @ifc::IfcTextureVertex.new(@ifc_model)
      texture_vert.coordinates = IfcManager::Types::List.new([u, v])
      texture_vert
    end

    def create_points(su_face)
      vertices = su_face.vertices
      vert_count = vertices.length
      i = 0
      while i < vert_count
        unless @vertices[vertices[i]]
          position = vertices[i].position.transform(@su_transformation)
          @vertices[vertices[i]] = @ifc::IfcCartesianPoint.new(@ifc_model, position)
        end
        i += 1
      end
    end
  end
end
