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
    require_relative 'classification_reference'
    require File.join(PLUGIN_PATH_LIB, 'skc_reader')

    class Classification
      attr_reader :name, :creator, :revision, :modified, :classification_references, :ifc_classification

      def initialize(ifc_model, classification_name, skc_file = nil)
        @ifc_model = ifc_model
        @name = classification_name
        @ifc_classification = nil
        @classification_references = {}
        load_skc(skc_file)
        @creator = nil
        @revision = nil
        @modified = nil
      end

      def load_skc(file_name = nil)
        file_name ||= "#{@name}.skc"
        classification = SKC.new(file_name)
        properties = classification.properties
        @creator = properties[:creator]
        @revision = properties[:revision]
        @modified = properties[:modified]
      end

      def get_ifc_classification
        @ifc_classification || IfcClassificationBuilder.build(@ifc_model) do |builder|
          builder.set_name(@name)
          builder.set_creator(@creator)
          builder.set_edition(@revision)
          builder.set_editiondate(@modified) if @modified
        end
      end

      def add_classification_reference(ifc_entity, classification_value, identification = nil, location = nil)
        unless @classification_references.key? classification_value
          @classification_references[classification_value] =
            ClassificationReference.new(@ifc_model, self, classification_value, identification, location)
        end
        @classification_references[classification_value].add_ifc_entity(ifc_entity)
      end
    end
  end
end
