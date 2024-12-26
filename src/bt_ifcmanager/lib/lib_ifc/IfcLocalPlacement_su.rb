# frozen_string_literal: true

#  IfcLocalPlacement_su.rb
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

require_relative '../transformation_helper'

module BimTools
  module IfcLocalPlacement_su
    attr_accessor :transformation, :ifc_total_transformation

    @@DEFAULT_TRANSFORMATION = Geom::Transformation.new.to_a.freeze

    def initialize(ifc_model, su_total_transformation = Geom::Transformation.new, placementrelto = nil)
      super
      @ifc_module = ifc_model.ifc_module

      # set parent placement
      @placementrelto = placementrelto # if placementrelto.is_a?(IfcLocalPlacement)
      
      raise('input must be sketchup transform') unless su_total_transformation.is_a?(Geom::Transformation)

      # Re-use default placement if no transformation is applied
      if su_total_transformation && su_total_transformation.to_a == @@DEFAULT_TRANSFORMATION
        @relativeplacement = ifc_model.default_placement
        @ifc_total_transformation = su_total_transformation
      else

        # (?) What happens with the scaling component?
        rotation_and_translation, scaling = TransformationHelper.decompose_transformation(su_total_transformation)

        @ifc_total_transformation = rotation_and_translation

        @transformation = if !@placementrelto.nil? && @placementrelto.ifc_total_transformation
                            @placementrelto.ifc_total_transformation.inverse * @ifc_total_transformation
                          else
                            @ifc_total_transformation
                          end

        # set relativeplacement
        @relativeplacement = @ifc_module::IfcAxis2Placement3D.new(ifc_model, @transformation)
      end
    end
  end
end
