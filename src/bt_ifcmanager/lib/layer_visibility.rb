# frozen_string_literal: true

#  layer_visibility.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcManager
    # Helper method that figures out if a layer REALLY is visible
    #   due to the new folder structure in SketchUp 2021
    #
    # @param [Sketchup::Layer] or [Sketchup::LayerFolder] layer
    # @return [true] if layer is visible
    def layer_visible?(layer)
      if layer.visible?
        if Sketchup.version_number < 2_100_000_000
          true
        elsif layer.folder
          layer_visible?(layer.folder)
        else
          true
        end
      else
        false
      end
    end
  end
end
