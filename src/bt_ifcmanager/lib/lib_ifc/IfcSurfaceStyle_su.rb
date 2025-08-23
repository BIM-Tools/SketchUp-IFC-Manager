# frozen_string_literal: true

#  IfcSurfaceStyle_su.rb
#
#  Copyright 2025 Jan Brouwer <jan@brewsky.nl>
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

require_relative '../../utils/uuid5'

module BimTools
  module IfcSurfaceStyle_su
    def initialize(_ifc_model, su_material)
      @su_material = su_material
      super
    end

    def ifcx
      return if @su_material.nil?

      # material_namespace_uri = 'https://identifier.buildingsmart.org/uri/buildingsmart-community/materials-demo/1.0/class/'

      {
        path: get_uuid,
        attributes: {
          'bsi::ifc::presentation::diffuseColor': extract_color(@su_material.color),
          'bsi::ifc::presentation::opacity': extract_opacity(@su_material)
        }
      }
    end

    def get_uuid
      if @su_material.nil? || @su_material.name.nil?
        warn 'Material or material name is not defined. UUID generation skipped.'
        return nil
      end

      unique_identifier = if @su_material.respond_to?(:persistent_id)
                            "#{@su_material.name}#{@su_material.persistent_id}"
                          else
                            @su_material.name
                          end

      IfcManager::Utils.create_uuid5('IfcSurfaceStyle', unique_identifier)
    end

    private

    def sanitize_name(name)
      name.gsub(/[^0-9A-Za-z]/, '_')
    end

    def extract_color(color)
      [color.red / 255.0, color.green / 255.0, color.blue / 255.0]
    end

    def extract_opacity(color)
      color.alpha
    end
  end
end
