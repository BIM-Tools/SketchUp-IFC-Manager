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
    require_relative 'classification_reference'
    require File.join(PLUGIN_PATH_LIB, 'skc_reader.rb')

    class Classification
      attr_reader :name, :creator, :revision, :modified, :classification_references, :ifc_classification

      DEFAULT_SOURCE_VALUE = 'unknown'
      DEFAULT_EDITION_VALUE = 'unknown'

      def initialize(ifc_model, classification_name, skc_file=nil)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @name = classification_name
        @ifc_classification = nil
        @classification_references = {}
        load_skc(skc_file)
      end

      def set_name(name)
        name = name << ' Classification' if @ifc_model.options[:classification_suffix]
        @ifc_classification.name = BimTools::IfcManager::IfcLabel.new(@ifc_model, name)
      end

      def set_creator(creator = nil)
        if creator
          @ifc_classification.source = BimTools::IfcManager::IfcLabel.new(@ifc_model, creator)
        elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.source = BimTools::IfcManager::IfcLabel.new(@ifc_model, DEFAULT_SOURCE_VALUE)
        end
      end

      def set_edition(edition = nil)
        if edition
          @ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(@ifc_model, edition)
        elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.edition = BimTools::IfcManager::IfcLabel.new(@ifc_model, DEFAULT_EDITION_VALUE)
        end
      end

      def set_editiondate(editiondate)
        time = Time.parse(editiondate)

        # IFC 4
        if @ifc.const_defined?(:IfcCalendarDate)
          date = @ifc::IfcCalendarDate.new(@ifc_model)
          date.daycomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.day)
          date.monthcomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.month)
          date.yearcomponent = BimTools::IfcManager::IfcInteger.new(@ifc_model, time.year)

        # IFC 2x3
        else
          date = BimTools::IfcManager::IfcDate.new(@ifc_model, time)
        end
        @ifc_classification.editiondate = date
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
        unless @ifc_classification
          @ifc_classification = @ifc::IfcClassification.new(@ifc_model)
          set_name(@name)
          set_creator(@creator)
          set_edition(@revision)
          set_editiondate(@modified) if @modified
        end
        return @ifc_classification
      end

      def add_classification_reference(ifc_entity, classification_value, identification=nil, location=nil)
        unless @classification_references.key? classification_value
          @classification_references[classification_value] =
            ClassificationReference.new(@ifc_model, self, classification_value, identification, location)
        end
        @classification_references[classification_value].add_ifc_entity(ifc_entity)
      end
    end
  end
end
