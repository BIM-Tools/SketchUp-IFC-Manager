#  IfcProductDefinitionShape_su.rb
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

require_relative 'list'

module BimTools
  module IfcProductDefinitionShape_su
    attr_accessor :globalid

    # @param ifc_model [IfcManager::IfcModel]
    # @param sketchup [Sketchup::ComponentDefinition]
    def initialize(ifc_model, sketchup)
      super
      @ifc = BimTools::IfcManager::Settings.ifc_module

      # Check if Mapped representation should be used
      if ifc_model.options[:mapped_items] # && (sketchup.count_instances > 1) # (?) Always use mapped items? also for objects that are used only once?
        representationtype = BimTools::IfcManager::IfcLabel.new(ifc_model, 'MappedRepresentation')
      else
        representationtype = BimTools::IfcManager::IfcLabel.new(ifc_model, 'Brep')
      end

      # set representation based on definition
      representation = @ifc::IfcShapeRepresentation.new(ifc_model, sketchup, representationtype)
      @representations = IfcManager::Ifc_List.new([representation])
    end
  end
end
