# frozen_string_literal: true

#  IfcTriangulatedFaceSet_su.rb
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
  module IfcTriangulatedFaceSet_su
    attr_accessor :globalid

    def ifcx
      usd_mesh = {
        'faceVertexIndices' => [],
        'points' => []
      }

      @coordinates.coordlist.each do |coord|
        usd_mesh['points'] << [coord[0].ifcx, coord[1].ifcx, coord[2].ifcx]
      end

      @coordindex.each do |index_list|
        usd_mesh['faceVertexIndices'] += index_list.map { |index| index.value - 1 } # Adjust for 0-based indexing
      end

      {
        'def' => 'over',
        'comment' => 'triangulated face set',
        'name' => @globalid.to_uuid,
        'attributes' => {
          'UsdGeom:Mesh' => usd_mesh
        }
      }
    end
  end
end
