#  IfcRelDecomposes_su.rb
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
#
#

require_relative File.join('IFC2X3', 'IfcMaterial.rb')
require_relative 'set.rb'

module BimTools
  module IfcRelDecomposes_su
    def to_json(arg=nil)
      if self.relatedobjects

        # only include non empty properties
        value = self.relatedobjects
        if value.items
          items_json = []
          value.items.each do |item|
            items_json << {
              "Class" => item.class.name.split('::Ifc').last,
              "ref" => item.globalid
            }
          end
          return items_json.to_json()
        else
          return nil
        end
      else
        return nil
      end
    end # to_json
  end # module IfcRelDecomposes_su
end # module BimTools