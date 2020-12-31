#  IfcInteger.rb
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

module BimTools::IfcManager

  # A defined type of simple data type Integer. (Required since a select
  #   type, i.e. IfcSimpleValue, cannot include directly simple types in
  #   its select list).
  class IfcInteger < Ifc_Type
    attr_accessor :long

    def initialize( value )
      begin
        @value = value.to_i
      rescue StandardError, TypeError => e
        print value << "cannot be converted to a Integer" << e
      end
    end
    
    def step()
      val = @value.to_s
      if @long
        val = add_long( val )
      end
      return val
    end
  end
end
