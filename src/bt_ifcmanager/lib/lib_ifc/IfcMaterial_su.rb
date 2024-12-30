# frozen_string_literal: true

#  IfcMaterial_su.rb
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
  module IfcMaterial_su
    def initialize(_ifc_model, su_material)
      @su_material = su_material
      super
    end

    def ifcx
      name = @name.value.gsub(/[^0-9A-Za-z]/, '_')
      shaders = ifc5_shaders(@su_material)

      [{
        'def' => 'def',
        'type' => 'UsdShade:Material',
        'name' => name,
        'children' => shaders
      }, {
        'def' => 'over',
        'name' => name,
        'attributes' => {
          'UsdShade:Material' => {
            'outputs:surface.connect' => {
              'ref' => "</#{name}/Shader.outputs:surface>"
            }
          }
        }

      }]
    end

    def ifc5_shaders(su_material)
      color = if su_material
                @su_material.color
              else
                Sketchup::Color.new(255, 255, 255, 255)
              end
      [
        {
          'def' => 'def',
          'type' => 'UsdShade:Shader',
          'name' => 'Shader',
          'attributes' => {
            'info:id' => 'UsdPreviewSurface',
            'inputs:diffuseColor' => [color.red / 255.0, color.green / 255.0, color.blue / 255.0],
            'inputs:opacity' => color.alpha / 255.0,
            'outputs:surface' => nil
          }
        }
      ]
    end
  end
end
