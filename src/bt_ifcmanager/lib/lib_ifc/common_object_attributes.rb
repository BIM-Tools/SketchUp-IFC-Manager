# frozen_string_literal: true

#  common_object_attributes.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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
  module CommonObjectAttributes
    # @param [IfcManager::IfcModel] ifc_model
    # @param [Sketchup::ComponentInstance] su_instance
    def add_common_attributes(ifc_model, su_instance)
      su_definition = su_instance.definition
      dictionaries = su_definition.attribute_dictionaries

      return unless dictionaries

      dict_reader = IfcManager::IfcDictionaryReader.new(ifc_model, self, dictionaries)
      dict_reader.set_attributes

      unless ifc_model.options[:type_properties]
        dict_reader.add_propertysets
        dict_reader.add_sketchup_definition_properties(ifc_model, self, su_definition)
        dict_reader.add_classifications
      end
      dict_reader.add_sketchup_instance_properties(ifc_model, self, su_instance)
    end
  end
end
