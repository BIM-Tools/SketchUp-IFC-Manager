#  select.rb
#
#  Copyright 2016 Jan Brouwer <jan@brewsky.nl>
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
  class select
    def initialize( window, name, options )
      @window = window
    end
    def add_selectbox( name )
      js_command = String.new
      js_command << "$( 'body' ).append( '<label for=\"" + name + "\">" + name + "</label> ');"
      js_command << "$( 'body' ).append( '<span><select id=\"" + name + "\" name=\"" + name + "\"></span> ');"
      #js_command << "$( '#" + name + "' ).attr('name','" + name + "');"
      #js_command << "$( '#" + name + "' ).val('FFFFFFFFFFFFFFFFFFF');"
      @window.execute_script( js_command )
    end # add_input_text
  end # class select
 end # module IfcManager
end # module BimTools
