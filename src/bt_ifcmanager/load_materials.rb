#  load_materials.rb
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

module BimTools
 module IfcManager
   
   # create new material for every name in list
   # unless a material with this name already exists
   def load_materials()
    list = Hash.new
    list['beton']          = [142, 142, 142]
    list['hout']           = [129, 90, 35]
    list['staal']          = [198, 198, 198]
    list['gips']           = [255, 255, 255]
    list['zink']           = [198, 198, 198]
    list['hsb']            = [204, 161, 0]
    list['metselwerk']     = [102, 51, 0]
    list['steen']          = [142, 142, 142]
    list['zetwerk']        = [198, 198, 198]
    list['tegel']          = [255, 255, 255]
    list['aluminium']      = [198, 198, 198]
    list['kunststof']      = [255, 255, 255]
    list['rvs']            = [198, 198, 198]
    list['pannen']         = [30, 30, 30]
    list['bitumen']        = [30, 30, 30]
    list['epdm']           = [30, 30, 30]
    list['isolatie']       = [255, 255, 50]
    list['kalkzandsteen']  = [255, 255, 255]
    list['metalstud']      = [198, 198, 198]
    list['gibo']           = [255, 255, 255]
    list['glas']           = [204, 255, 255]
    list['multiplex']      = [255, 216, 101]
    list['cementdekvloer'] = [198, 198, 198]
    
    list.each do | name, color|
      unless Sketchup.active_model.materials[ name ]
        mat = Sketchup.active_model.materials.add( name )
        mat.color = color
      end
    end
   end
 end # module IfcManager
end # module BimTools