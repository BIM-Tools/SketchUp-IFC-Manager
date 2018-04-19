#  IfcProject.rb
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

require_relative File.join('IFC2X3', 'IfcUnitAssignment.rb')
require_relative File.join('IFC2X3', 'IfcSIUnit.rb')

module BimTools
  module IfcProject_su
    attr_accessor :su_object
    def initialize(ifc_model, sketchup)
      super
      self.su_object=(sketchup)
      @ifc_model = ifc_model
      
      # IfcUnitAssignment
      @unitsincontext = BimTools::IFC2X3::IfcUnitAssignment.new( ifc_model )
      @unitsincontext.units = IfcManager::Ifc_Set.new()
      mm = BimTools::IFC2X3::IfcSIUnit.new( ifc_model )
      mm.dimensions = '*'
      mm.unittype = '.LENGTHUNIT.'
      mm.prefix = '.MILLI.'
      mm.name = '.METRE.'
      @unitsincontext.units.add( mm )
      m2 = BimTools::IFC2X3::IfcSIUnit.new( ifc_model )
      m2.dimensions = '*'
      m2.unittype = '.AREAUNIT.'
      m2.name = '.SQUARE_METRE.'
      @unitsincontext.units.add( m2 )
      m3 = BimTools::IFC2X3::IfcSIUnit.new( ifc_model )
      m3.dimensions = '*'
      m3.unittype = '.VOLUMEUNIT.'
      m3.name = '.CUBIC_METRE.'
      @unitsincontext.units.add( m3 )
    end # def initialize
    
    def su_object=(sketchup)
      @name = "Default Project"
      @description = "Description of Default Project"
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance)
        @su_object = sketchup
        
        # get properties from su object and add them to ifc object
        unless @su_object.definition.name.nil? || @su_object.definition.name == ""
          @name = BimTools::IfcManager::IfcLabel.new( @su_object.definition.name )
          @description = BimTools::IfcManager::IfcLabel.new( @su_object.definition.description )
        end
      else
        unless @ifc_model.su_model.name.nil? || @ifc_model.su_model.name == ""
          @name = @ifc_model.su_model.name
          @description = @ifc_model.su_model.description
        end
      end
      #@name = BimTools::IfcManager::IfcLabel.new( name )
      #@description = BimTools::IfcManager::IfcText.new( description )
    end
    
    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end # module IfcProject_su
end # module BimTools
