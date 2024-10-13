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
  module IfcManager
    class IfcFacetedBrepBuilder
      attr_reader :ifc_faceted_brep

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.validate
        builder.ifc_faceted_brep
      end

      def initialize(ifc_model)
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @vertices = {}

        @ifc_faceted_brep = @ifc_module::IfcFacetedBrep.new(ifc_model)

        @ifc_faceted_brep
      end

      def validate
        raise ArgumentError, 'Missing value for IfcFacetedBrep Outer' unless @ifc_faceted_brep.outer
      end

      def set_outer(su_faces)
        @ifc_faceted_brep.outer = @ifc_module::IfcClosedShell.new(@ifc_model, su_faces)
        faces = su_faces.map { |face| add_face(face) }
        @ifc_faceted_brep.outer.cfsfaces = IfcManager::Types::Set.new(faces)
      end

      # (!) This method must be called before adding faces
      # @todo make this more robust
      def set_transformation(transformation)
        @su_transformation = transformation

        # multiply all transformation values to see if the component is flipped
        @flipped = !(@su_transformation.xaxis * @su_transformation.yaxis % @su_transformation.zaxis < 0)
      end

      def set_contextofitems(representationcontext)
        @ifc_faceted_brep.contextofitems = representationcontext
      end

      def set_representationidentifier(identifier = 'Body')
        @ifc_faceted_brep.representationidentifier = Types::IfcLabel.new(@ifc_model, identifier)
      end

      def set_items(items = [])
        @ifc_faceted_brep.items = Types::Set.new(items)
      end

      def add_item(item)
        @ifc_faceted_brep.items.add(item)
      end

      def set_styling(su_material)
        if @ifc_model.options[:colors] && !@ifc_model.materials[su_material]
          @ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(@ifc_model, su_material)
        end
        # @ifc_model.materials[su_material].add_to_styling(@ifc_faceted_brep)
      end

      def add_face(su_face)
        create_points(su_face)
        ifc_face = @ifc_module::IfcFace.new(@ifc_model)
        texture_map = nil
        su_material = su_face.material

        if @ifc_model.textures && su_material && su_material.texture

          # check if material exists
          unless @ifc_model.materials.key?(su_material)
            @ifc_model.materials[su_material] = IfcManager::MaterialAndStyling.new(@ifc_model, su_material)
          end

          # IFC 4
          if @ifc_module::IfcTextureMap.method_defined? :maps
            image_texture = @ifc_model.materials[su_material].image_texture
            if image_texture
              texture_map = @ifc_module::IfcTextureMap.new(@ifc_model)
              uv_helper = su_face.get_UVHelper(true, true, @ifc_model.textures)
              texture_map.maps = IfcManager::Types::List.new([image_texture])
              texture_map.mappedto = ifc_face
            end
          end
        end
        bounds = su_face.loops.map { |loop| create_loop(loop, texture_map, uv_helper) }
        ifc_face.bounds = IfcManager::Types::Set.new(bounds)
        ifc_face
      end

      def create_loop(loop, tex_map = nil, uv_helper = nil)
        # differenciate between inner and outer loops/bounds
        bound = if loop.outer?
                  @ifc_module::IfcFaceOuterBound.new(@ifc_model)
                else
                  @ifc_module::IfcFaceBound.new(@ifc_model)
                end

        points = loop.vertices.map { |vert| @vertices[vert] }
        polyloop = @ifc_module::IfcPolyLoop.new(@ifc_model)
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
        texture_vert = @ifc_module::IfcTextureVertex.new(@ifc_model)
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
            @vertices[vertices[i]] = @ifc_module::IfcCartesianPoint.new(@ifc_model, position)
          end
          i += 1
        end
      end
    end
  end
end
