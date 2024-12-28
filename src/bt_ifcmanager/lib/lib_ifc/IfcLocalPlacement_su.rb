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

module BimTools
  module IfcLocalPlacement_su
    attr_accessor :transformation, :ifc_total_transformation

    DEFAULT_TRANSFORMATION = Geom::Transformation.new.to_a.freeze

    def initialize(ifc_model, su_total_transformation = Geom::Transformation.new, placementrelto = nil)
      raise('input must be sketchup transform') unless su_total_transformation.is_a?(Geom::Transformation)

      super
      @ifc_module = ifc_model.ifc_module
      @placementrelto = placementrelto
      @ifc_total_transformation = su_total_transformation

      @transformation = calculate_transformation

      @relativeplacement = determine_relative_placement(ifc_model)
    end

    private

    def calculate_transformation
      return @ifc_total_transformation unless @placementrelto && @placementrelto.ifc_total_transformation

      @placementrelto.ifc_total_transformation.inverse * @ifc_total_transformation
    end

    def determine_relative_placement(ifc_model)
      return ifc_model.default_placement if default_transformation?

      @ifc_module::IfcAxis2Placement3D.new(ifc_model, @transformation)
    end

    def default_transformation?
      @transformation.to_a == DEFAULT_TRANSFORMATION
    end
  end
end
