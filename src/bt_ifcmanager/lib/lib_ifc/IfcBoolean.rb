#  IfcBoolean.rb
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

require_relative 'Ifc_Type.rb'

module BimTools
 module IfcManager
  class IfcBoolean < Ifc_Type
    def initialize( value )
      @value = true?(value) # (!) type check? error when not explicitly string false?
    end # def initialize
    def step()
      if @value
        val = ".T."
      else
        val = ".F."
      end
      if @long
        val = add_long( val )
      end
      return val
    end # def step

    def to_json(arg=nil)
      return (@value).inspect   
    end # def to_json
    
    def true?(obj)
      obj.to_s == "true"
    end
  end # class IfcBoolean
 end # module IfcManager
end # module BimTools
