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

require_relative 'IfcNormalisedRatioMeasure'

module BimTools
  module IfcStyledItem_su
    include BimTools::IfcManager::Settings.ifc_module

    def initialize(ifc_model, brep, material = nil)
      super
      instance_variable_set(:@attr, ([:Item] + attributes))

      styleassignment = IfcPresentationStyleAssignment.new(ifc_model, material)
      surfacestyle = IfcSurfaceStyle.new(ifc_model, material)
      surfacestylerendering = IfcSurfaceStyleRendering.new(ifc_model, material)
      colourrgb = IfcColourRgb.new(ifc_model, material)

      # Workaround for bug in IFC XSD's forward from IFC4, missing "item" attribute
      unless attributes.include? :Item
        @item = nil
        define_singleton_method(:attributes) do
          attributes = self.class.attributes
          return [:Item] + attributes
          return attributes
        end
        define_singleton_method(:item) do
          return @item
        end
        define_singleton_method(:item=) do |item|
          return @item = item
        end
      end

      @item = brep
      @styles = IfcManager::Ifc_Set.new([styleassignment])

      styleassignment.styles = IfcManager::Ifc_Set.new([surfacestyle])

      surfacestyle.side = :BOTH
      surfacestyle.styles = IfcManager::Ifc_Set.new([surfacestylerendering])

      surfacestylerendering.surfacecolour = colourrgb
      surfacestylerendering.reflectancemethod = :NOTDEFINED

      if material

        # add transparency, converted from Sketchup's alpha value
        surfacestylerendering.transparency = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(1 - material.alpha)

        # add color values, converted from 0/255 to fraction
        colourrgb.red = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(material.color.red.to_f / 255)
        colourrgb.green = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(material.color.green.to_f / 255)
        colourrgb.blue = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(material.color.blue.to_f / 255)
      else

        # (?) use default values == white
        surfacestylerendering.transparency = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(0.0)
        colourrgb.red = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(1.0)
        colourrgb.green = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(1.0)
        colourrgb.blue = BimTools::IfcManager::IfcNormalisedRatioMeasure.new(1.0)
      end
    end
  end
end
