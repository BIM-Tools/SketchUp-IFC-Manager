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
    attr_accessor :su_object

    def initialize(ifc_model, sketchup)
      super
      @ifc = IfcManager::Settings.ifc_module
      self.su_object = (sketchup)
      @ifc_model = ifc_model

      # Set project units to sketchup units
      @unitsincontext = @ifc::IfcUnitAssignment.new(@ifc_model)
    end

    def su_object=(sketchup)
      @name = IfcManager::Types::IfcLabel.new(@ifc_model, 'default project')
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance)
        @su_object = sketchup

        # get properties from Sketchup object and add them to ifc object
        unless @su_object.definition.name.empty?
          @name = IfcManager::Types::IfcLabel.new(@ifc_model,
                                                     @su_object.definition.name)
        end
        unless @su_object.definition.description.empty?
          @description = IfcManager::Types::IfcLabel.new(@ifc_model,
                                                            @su_object.definition.description)
        end
      else

        # get properties from Sketchup Model and add them to ifc object
        unless @ifc_model.su_model.name.empty?
          @name = IfcManager::Types::IfcLabel.new(@ifc_model,
                                                     @ifc_model.su_model.name)
        end
        unless @ifc_model.su_model.description.empty?
          @description = IfcManager::Types::IfcLabel.new(@ifc_model,
                                                            @ifc_model.su_model.description)
        end
      end
    end

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end
end
