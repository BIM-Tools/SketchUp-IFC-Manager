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
require_relative 'PropertyReader'

module BimTools
  module IfcGroup_su
    # @param [IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentDefinition] sketchup
    def initialize(ifc_model, sketchup = nil)
      super
      @ifc_module = ifc_model.ifc_module
      @rel = @ifc_module::IfcRelAssignsToGroup.new(ifc_model)
      @rel.relatinggroup = self
      @rel.relatedobjects = IfcManager::Types::Set.new

      # (!) Functionalty and code is similar to IfcProduct, should be merged
      if sketchup.is_a?(Sketchup::Group) || sketchup.is_a?(Sketchup::ComponentInstance)

        # get properties from su object and add them to ifc object
        definition = sketchup.definition

        # (?) set name, here? is this a duplicate?
        @name = IfcManager::Types::IfcLabel.new(ifc_model, definition.name)

        # get attributes from su object and add them to IfcProduct
        dict_reader = IfcManager::IfcDictionaryReader.new(ifc_model, self, definition.attribute_dictionaries)
        dict_reader.set_attributes
        dict_reader.add_propertysets
        dict_reader.add_classifications

        # (!) @todo
        # Add ifc_model.options[:attributes] as parameter to dict_reader.set_properties()
        #
        #
        # if ifc_model.options[:attributes]
        #   ifc_model.options[:attributes].each do |attr_dict_name|
        #     # Only add definition propertysets when no TypeProduct is set
        #     collect_psets(ifc_model, @su_object.definition.attribute_dictionary(attr_dict_name)) unless @type_product
        #     collect_psets(ifc_model, @su_object.attribute_dictionary(attr_dict_name))
        #   end
        # else
      end
    end

    def add(entity)
      @rel.relatedobjects.add(entity)
    end

    # add export summary for IfcProducts
    def step
      @ifc_model.summary_add(self.class.name.split('::').last)
      super
    end
  end
end
