# frozen_string_literal: true

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

require_relative 'ifc_types'
require_relative 'common_object_attributes'

module BimTools
  module IfcGroup_su
    include BimTools::CommonObjectAttributes

    # @param [IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentInstance] su_instance
    def initialize(ifc_model, su_instance = nil)
      super
      @ifc_module = ifc_model.ifc_module

      @rel = @ifc_module::IfcRelAssignsToGroup.new(ifc_model)
      @rel.relatinggroup = self
      @rel.relatedobjects = IfcManager::Types::Set.new

      # (?) set name, here? is this a duplicate?
      @name = IfcManager::Types::IfcLabel.new(ifc_model, su_instance.definition.name)

      add_instance_data(ifc_model, su_instance)
    end

    def add(entity)
      @rel.relatedobjects.add(entity)
    end

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end

    # add export summary for IfcProducts
    def ifcx
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end
end
