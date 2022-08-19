# frozen_string_literal: true

#  classifications.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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
  module IfcManager
    require_relative 'classification'
    require File.join(PLUGIN_PATH_LIB, 'skc_reader.rb')

    # Keeps track of all classifications in a IFC model
    class Classifications
      def initialize(ifc_model)
        @ifc_model = ifc_model
        @classifications = {}
      end

      # Get classification by name and create if it doesn't exist
      #
      # @return [IfcManager::Classification]
      def get_classification_by_name(name, skc_file = nil)
        if @classifications.key? name
          @classifications[name]
        else
          @classifications[name] = Classification.new(@ifc_model, name, skc_file)
        end
      end

      def add_classification_to_entity(ifc_entity, classification_name, classification_value, classification_dictionary)
        classification = get_classification_by_name(classification_name)
        classification.add_classification_reference(ifc_entity, classification_value,
                                                    get_identification(classification_dictionary), get_location(classification_dictionary))
      end

      def get_identification(classification_dictionary)
        classification_dictionary.attribute_dictionaries.each do |dictionary|
          if %w[identification itemreference class-codenotatie].include? dictionary.name.downcase
            if value = dictionary['value']
              return value
            elsif value_dictionary = dictionary.attribute_dictionaries[dictionary.name]
              return value_dictionary['value']
            end
          end
        end
        nil
      end

      def get_location(classification_dictionary)
        if dictionary = classification_dictionary['Location']
          if value = dictionary['value']
            return value
          elsif value_dictionary = dictionary.attribute_dictionaries[dictionary.name]
            return value_dictionary['value']
          end
        end
        nil
      end
    end
  end
end
