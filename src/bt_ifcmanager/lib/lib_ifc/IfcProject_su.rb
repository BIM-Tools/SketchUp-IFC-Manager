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

module BimTools
  module IfcProject_su
    
    require_relative File.join('IFC2X3', 'IfcAxis2Placement3D.rb')
    require_relative File.join('IFC2X3', 'IfcCartesianPoint.rb')
    require_relative File.join('IFC2X3', 'IfcDirection.rb')
    require_relative File.join('IFC2X3', 'IfcUnitAssignment.rb')
    require_relative File.join('IFC2X3', 'IfcSIUnit.rb')
    require_relative File.join('IFC2X3', 'IfcRelAggregates.rb')
    
    def initialize(ifc_model, sketchup)
      super
      self.name = "'Default Project'"
      @ifc_model = ifc_model
      
      # IfcUnitAssignment
      self.unitsincontext = IFC2X3::IfcUnitAssignment.new( ifc_model )
      self.unitsincontext.units = IfcManager::Ifc_Set.new()
      mm = IFC2X3::IfcSIUnit.new( ifc_model )
      mm.dimensions = '*'
      mm.unittype = '.LENGTHUNIT.'
      mm.prefix = '.MILLI.'
      mm.name = '.METRE.'
      self.unitsincontext.units.add( mm )
      m2 = IFC2X3::IfcSIUnit.new( ifc_model )
      m2.dimensions = '*'
      m2.unittype = '.AREAUNIT.'
      m2.name = '.SQUARE_METRE.'
      self.unitsincontext.units.add( m2 )
      m3 = IFC2X3::IfcSIUnit.new( ifc_model )
      m3.dimensions = '*'
      m3.unittype = '.VOLUMEUNIT.'
      m3.name = '.CUBIC_METRE.'
      self.unitsincontext.units.add( m3 )
    end # def initialize
    
  end # module IfcProject_su
end # module BimTools
