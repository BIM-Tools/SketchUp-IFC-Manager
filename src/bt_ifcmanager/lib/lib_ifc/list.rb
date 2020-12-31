#  list.rb
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

module BimTools
 module IfcManager
  class Ifc_List
    attr_accessor :items
    def initialize( items=nil )
      if items
        @items = items
      else
        @items = Array.new
      end
    end # def initialize
    def add( entity )
      @items << entity
    end # def add
    def first()
      return @items.first
    end # def add
    def step()
      line = String.new
      $i = 0
      $num = @items.length
      while $i < $num  do
        item = @items[$i]
        if item.is_a? String
          line << item
        else
          line << item.ref
        end
        
        #skip the , for the last element
        unless $i == $num - 1
          line << ","
        end
        $i +=1
      end
      return "(#{line})"
    end # def step
  end # class Ifc_List
 end # module IfcManager
end # module BimTools