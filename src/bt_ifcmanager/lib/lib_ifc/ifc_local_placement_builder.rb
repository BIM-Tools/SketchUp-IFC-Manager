# frozen_string_literal: true

#  ifc_local_placement_builder.rb
#
#  Copyright 2023 Jan Brouwer <jan@brewsky.nl>
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
# The IfcLocalPlacementBuilder class is responsible for building an IfcLocalPlacement object.
# It provides methods to set the relative placement of the local placement.

require_relative 'ifc_types'

module BimTools
  module IfcManager
    class IfcLocalPlacementBuilder
      attr_reader :ifc_local_placement

      # Builds an IfcLocalPlacement object.
      # An IfcLocalPlacement defines the relative placement of a product in relation to the placement of another product or the absolute placement of a product within the geometric representation context of the project.
      #
      # @param ifc_model [Object] The IFC model object.
      # @return [@ifc::IfcLocalPlacement] The IfcLocalPlacement object.
      def self.build(ifc_model, su_total_transformation = nil, placementrelto = nil)
        builder = new(ifc_model, su_total_transformation, placementrelto)
        yield(builder)
        builder
      end

      # Initializes a new instance of the IfcLocalPlacementBuilder class.
      #
      # @param ifc_model [Object] The IFC model object.
      def initialize(ifc_model, su_total_transformation = nil, placementrelto = nil)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_local_placement = @ifc::IfcLocalPlacement.new(ifc_model)

        # set parent placement
        @placementrelto = placementrelto # if placementrelto.is_a?(IfcLocalPlacement)

        return unless su_total_transformation.is_a?(Geom::Transformation)

        # fix y-axis direction if flipped
        t = su_total_transformation
        axis_fix = if t.xaxis.cross(t.yaxis).samedirection?(t.zaxis)
                     Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1])
                   else
                     Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, -1, 0], [0, 0, 1])
                   end

        # strip out scaling
        t = su_total_transformation.to_a
        x = t[0..2].normalize # is the xaxis
        y = t[4..6].normalize # is the yaxis
        z = t[8..10].normalize # is the zaxis
        no_scale = Geom::Transformation.axes(su_total_transformation.origin, x, y, z)

        @ifc_total_transformation = no_scale * axis_fix

        @transformation = if !@placementrelto.nil? && @placementrelto.ifc_total_transformation
                            @placementrelto.ifc_total_transformation.inverse * @ifc_total_transformation
                          else
                            @ifc_total_transformation
                          end

        # set relativeplacement
        @relativeplacement = @ifc::IfcAxis2Placement3D.new(ifc_model, @transformation)
      end

      # Sets the placement of the IfcLocalPlacement relative to another placement.
      #
      # @param placement_rel_to [@ifc::IfcObjectPlacement] Reference to object placement that provides the relative placement with its placement in a grid, local coordinate system or linear referenced placement. If it is omitted, then in the case of linear placement it is established by the origin of horizontal alignment of the referenced IfcAlignment Axis. In the case of local placement it is established by the geometric representation context.
      def set_placement_rel_to(placement_rel_to)
        @ifc_local_placement.relativeplacement = placement_rel_to
      end

      # Sets the relative placement of the IfcLocalPlacement.
      #
      # @param relative_placement [@ifc::IfcAxis2Placement] Geometric placement that defines the transformation from the related coordinate system into the relating. The placement can be either 2D or 3D, depending on the dimension count of the coordinate system.
      def set_relative_placement(relative_placement)
        @ifc_local_placement.relativeplacement = relative_placement
      end
    end
  end
end
