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

require 'date'

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
        @ifc_module = ifc_model.ifc_module
        @ifc_model = ifc_model
        @ifc_classification = @ifc_module::IfcClassification.new(@ifc_model)
        # @ifc_model.classifications[name] = @ifc_classification
      end

      def set_name(name)
        @ifc_classification.name = Types::IfcLabel.new(@ifc_model, name)
      end

      def set_source(source = nil)
        if source
          @ifc_classification.source = Types::IfcLabel.new(@ifc_model, source)
        elsif @ifc_model.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.source = Types::IfcLabel.new(@ifc_model, DEFAULT_SOURCE_VALUE)
        end
      end

      def set_edition(edition = nil)
        if edition
          @ifc_classification.edition = Types::IfcLabel.new(@ifc_model, edition)
        elsif @ifc_model.ifc_version == 'IFC 2x3'

          # IFC 2x3
          @ifc_classification.edition = Types::IfcLabel.new(@ifc_model, DEFAULT_EDITION_VALUE)
        end
      end

      def set_editiondate(editiondate)
        if editiondate
          date_time = DateTime.parse(editiondate)

          # IFC 4
          if @ifc_module.const_defined?(:IfcCalendarDate)
            date = @ifc_module::IfcCalendarDate.new(@ifc_model)
            date.daycomponent = Types::IfcInteger.new(@ifc_model, date_time.day)
            date.monthcomponent = Types::IfcInteger.new(@ifc_model, date_time.month)
            date.yearcomponent = Types::IfcInteger.new(@ifc_model, date_time.year)

          # IFC 2x3
          else
            date = Types::IfcDate.new(@ifc_model, date_time)
          end
          @ifc_classification.editiondate = date
        end
      end

      def set_location(location = nil)
        if location && defined?(@ifc_classification.location)
          @ifc_classification.location = IfcManager::Types::IfcURIReference.new(@ifc_model, location)
        end
      end
    end
  end
end
