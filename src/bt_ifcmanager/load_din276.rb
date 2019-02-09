#  load_din276.rb
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

#(mp) This method loads the DIN 276-1 classification schema
module BimTools
 module IfcManager
  def load_din276() # (!) should be load_classifications?
    unless Sketchup.active_model.classifications["DIN 276-1"]
      c = Sketchup.active_model.classifications
      file = File.join(PLUGIN_PATH_LIB, 'DIN 276-1.skc')
      c.load_schema(file) if !file.nil?
    end
    
    # also check if IFC2X3 is loaded
    unless Sketchup.active_model.classifications["IFC 2x3"]
      c = Sketchup.active_model.classifications
      file = Sketchup.find_support_file('IFC 2x3.skc', 'Classifications')
      c.load_schema(file) if !file.nil?
    end
  end # def load_din276
 end # module IfcManager
end # module BimTools
