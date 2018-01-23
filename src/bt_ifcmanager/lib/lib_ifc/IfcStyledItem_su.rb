#  IfcStyledItem_su.rb
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

require_relative File.join('IFC2X3', 'IfcPresentationStyleAssignment.rb')
require_relative File.join('IFC2X3', 'IfcSurfaceStyle.rb')
require_relative File.join('IFC2X3', 'IfcSurfaceStyleRendering.rb')
require_relative File.join('IFC2X3', 'IfcColourRgb.rb')

module BimTools
  module IfcStyledItem_su
    def initialize(ifc_model, brep, material)
      super
      
      styleassignment = BimTools::IFC2X3::IfcPresentationStyleAssignment.new( ifc_model, material )
      surfacestyle = BimTools::IFC2X3::IfcSurfaceStyle.new( ifc_model, material )
      surfacestylerendering = BimTools::IFC2X3::IfcSurfaceStyleRendering.new( ifc_model, material )
      colourrgb = BimTools::IFC2X3::IfcColourRgb.new( ifc_model, material )
      
      @item = brep
      @styles = IfcManager::Ifc_Set.new( [styleassignment] )
      
      styleassignment.styles = IfcManager::Ifc_Set.new( [surfacestyle] )
      
      surfacestyle.side = '.BOTH.'
      surfacestyle.styles = IfcManager::Ifc_Set.new( [surfacestylerendering] )
      
      surfacestylerendering.surfacecolour = colourrgb
      surfacestylerendering.transparency = material.alpha.to_s
      surfacestylerendering.reflectancemethod = '.NOTDEFINED.'
      
      # add color values, converted from 0/255 to fraction
      colourrgb.red = (material.color.red.to_f / 255).to_s
      colourrgb.green = (material.color.green.to_f / 255).to_s
      colourrgb.blue = (material.color.blue.to_f / 255).to_s
      
    end # def initialize
    
  end # module IfcStyledItem_su
end # module BimTools