#  IfcGroup_su.rb
#
#  Copyright 2021 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'set.rb'
# require_relative File.join('IFC2X3', 'IfcRelAssignsToGroup.rb')

module BimTools
  module IfcGroup_su
    # @parameter ifc_model [IfcManager::IfcModel]
    # @parameter sketchup [Sketchup::ComponentDefinition]
    def initialize(ifc_model, sketchup=nil)
      super

      @rel = BimTools::IFC2X3::IfcRelAssignsToGroup.new( ifc_model )
      @rel.relatinggroup = self
      @rel.relatedobjects = IfcManager::Ifc_Set.new()
    end
    
    def add(entity)
      @rel.relatedobjects.add(entity)
    end
  end
end
