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

require_relative 'list.rb'

module BimTools
  module IfcProductDefinitionShape_su
    include BimTools::IfcManager::Settings.ifc_module

    attr_accessor :globalid
    # @parameter ifc_model [IfcManager::IfcModel]
    # @parameter sketchup [Sketchup::ComponentDefinition]
    def initialize(ifc_model, sketchup)
      super

      # Check if Mapped representation should be used
      if (ifc_model.options[:mapped_items]) && (sketchup.count_instances > 1)
        representationtype = BimTools::IfcManager::IfcLabel.new( "MappedRepresentation" )
      else
        representationtype = BimTools::IfcManager::IfcLabel.new( "Brep" )
      end

      # set representation based on definition
      representation = IfcShapeRepresentation.new( ifc_model , sketchup, representationtype)
      @representations = IfcManager::Ifc_List.new([representation])
    end # def initialize
  end # module IfcProductDefinitionShape_su
end # module BimTools
