# frozen_string_literal: true

#  ifc_classification_reference_builder.rb
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
    class IfcClassificationReferenceBuilder
      attr_reader :ifc_classification_reference

      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_classification_reference
      end

      def initialize(ifc_model)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_classification_reference = @ifc::IfcClassificationReference.new(ifc_model)
      end

      def set_location(location)
        if Settings.ifc_version == 'IFC 2x3'
          @ifc_classification_reference.location = IfcManager::Types::IfcLabel.new(@ifc_model, location)
        else
          @ifc_classification_reference.location = IfcManager::Types::IfcURIReference.new(@ifc_model, location)
        end
      end

      def set_identification(identification)
        identifier = IfcManager::Types::IfcIdentifier.new(@ifc_model, identification)

        # IFC 2x3
        if @ifc::IfcClassificationReference.method_defined?(:itemreference)
          @ifc_classification_reference.itemreference = identifier

        # IFC 4
        else
          @ifc_classification_reference.identification = identifier
        end
      end

      def set_name(name)
        @ifc_classification_reference.name = IfcManager::Types::IfcLabel.new(@ifc_model, name)
      end

      def set_referencedsource(ifc_classification)
        @ifc_classification_reference.referencedsource = ifc_classification
      end
    end
  end
end
