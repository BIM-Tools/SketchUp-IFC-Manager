#  IfcLabel.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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
  class IfcLabel < Ifc_Type
    def initialize( value )
      begin
        @value = value.to_s
      rescue StandardError, TypeError => e
        print value + "cannot be converted to a String" + e
        
        # (!) Label may not be longer than 255 characters
        
      end
    end # def initialize
    
    # generate step object output string
    # adding long = true returns a full object string
    def step()
      str_replace = replace_char( @value )
      val = "'#{str_replace}'"
      if @long
        val = add_long( val )
      end
      return val
    end # def step
  end # class IfcLabel
 end # module IfcManager
end # module BimTools
