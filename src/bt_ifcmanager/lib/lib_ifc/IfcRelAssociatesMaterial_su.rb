# frozen_string_literal: true

#  IfcRelAssociatesMaterial_su.rb
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
  module IfcRelAssociatesMaterial_su
    def ifcx
      @relatedobjects.map do |relatedobject|
        {
          'def' => 'over',
          'name' => relatedobject.globalid.ifcx,
          'attributes' => {
            'UsdShade:MaterialBindingAPI' => {
              'material:binding' => {
                'ref' => "</#{@relatingmaterial.name.value.gsub(/[^0-9A-Za-z]/, '_')}>"
              }
            }
          }
        }
      end
    end
  end
end
