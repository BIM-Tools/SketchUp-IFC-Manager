# frozen_string_literal: true

#  classification.rb
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
    require_relative 'ifc_classification_builder'
    require_relative 'ifc_classification_reference_builder'
    require File.join(PLUGIN_PATH_LIB, 'skc_reader')

    class Classification
      attr_reader :name, :creator, :revision, :modified, :classification_references, :ifc_classification

      def initialize(ifc_model, classification_name, skc_file = nil)
        @ifc_model = ifc_model
        @name = classification_name
        @ifc_classification = nil
        @classification_references = {}
        @source = nil
        @edition = nil
        @editiondate = nil
        @location = nil
        load_skc(skc_file)
        get_classifiction_details
      end

      def load_skc(file_name = nil)
        file_name ||= "#{@name}.skc"
        properties = SKC.new(file_name).properties
        @source = properties[:creator]
        @edition = properties[:revision]
        @editiondate = properties[:modified]
      rescue StandardError => e
        puts "Error: #{e.message}. Skipping SKC file: #{file_name}"
      end

      def get_ifc_classification
        @ifc_classification ||= IfcClassificationBuilder.build(@ifc_model) do |builder|
          builder.set_name(@name)
          builder.set_source(@source)
          builder.set_edition(@edition)
          builder.set_editiondate(@editiondate)
          builder.set_location(@location)
        end
      end

      def get_classifiction_details
        su_model = @ifc_model.su_model
        return unless project_data = su_model.attribute_dictionaries['IfcManager']
        return unless classifications = project_data.attribute_dictionaries['Classifications']

        @source = classifications.get_attribute(@name, 'source')
        @edition = classifications.get_attribute(@name, 'edition')
        @editiondate = classifications.get_attribute(@name, 'editiondate')
        @location = classifications.get_attribute(@name, 'location')
      end

      def add_classification_reference(ifc_entity, classification_value, identification = nil, location = nil,
                                       name = nil)
        ifc_classification = get_ifc_classification
        unless @classification_references.key? classification_value
          @classification_references[classification_value] =
            IfcClassificationReferenceBuilder.build(@ifc_model, @name) do |builder|
              builder.set_location(location) if location
              builder.set_referencedsource(ifc_classification)
              builder.set_identification(identification) if identification
              builder.set_name(name) if name
            end
        end
        @classification_references[classification_value].add_ifc_entity(ifc_entity)
      end
    end
  end
end
