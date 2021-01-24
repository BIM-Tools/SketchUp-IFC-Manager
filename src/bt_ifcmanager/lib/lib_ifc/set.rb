#  set.rb
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

module BimTools::IfcManager
  class Ifc_Set
    attr_accessor :items
    def initialize( items=nil )
      if items
        @items = items.to_set
      else
        @items = Set.new
      end
    end

    def add( entity )
      unless @items.include?(entity)
        @items << entity
      end
    end

    def item_to_step(item)
      if item.is_a? String
        return item
      else
        return item.ref
      end
    end

    def step()
      item_strings = @items.map { |item| item_to_step(item) }
      return "(#{item_strings.join(",")})"
    end
  end
end