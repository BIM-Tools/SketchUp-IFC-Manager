# frozen_string_literal: true

#  ifc_classification_builder.rb
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
    class IfcClassificationBuilder
      attr_reader :ifc_classification

      DEFAULT_SOURCE_VALUE = 'unknown'
      DEFAULT_EDITION_VALUE = 'unknown'

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_classification
      end

      def initialize(ifc_model)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_classification = @ifc::IfcClassification.new(@ifc_model)
        # @ifc_model.classifications[name] = @ifc_classification
      end

      def set_name(name)
        @ifc_classification.name = BimTools::IfcManager::Types::IfcLabel.new(@ifc_model, name)
      end

      def set_source(source = nil)
        if source
          @ifc_classification.source = BimTools::IfcManager::Types::IfcLabel.new(@ifc_model, source)
        elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.source = BimTools::IfcManager::Types::IfcLabel.new(@ifc_model, DEFAULT_SOURCE_VALUE)
        end
      end

      def set_edition(edition = nil)
        if edition
          @ifc_classification.edition = BimTools::IfcManager::Types::IfcLabel.new(@ifc_model, edition)
        elsif BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.edition = BimTools::IfcManager::Types::IfcLabel.new(@ifc_model, DEFAULT_EDITION_VALUE)
        end
      end

      def set_editiondate(editiondate)
        time = Time.parse(editiondate)

        # IFC 4
        if @ifc.const_defined?(:IfcCalendarDate)
          date = @ifc::IfcCalendarDate.new(@ifc_model)
          date.daycomponent = BimTools::IfcManager::Types::IfcInteger.new(@ifc_model, time.day)
          date.monthcomponent = BimTools::IfcManager::Types::IfcInteger.new(@ifc_model, time.month)
          date.yearcomponent = BimTools::IfcManager::Types::IfcInteger.new(@ifc_model, time.year)

        # IFC 2x3
        else
          date = BimTools::IfcManager::Types::IfcDate.new(@ifc_model, time)
        end
        @ifc_classification.editiondate = date
      end
    end
  end
end
