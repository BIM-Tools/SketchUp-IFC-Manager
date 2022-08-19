# frozen_string_literal: true

#  classification_reference.rb
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
    require_relative 'classification_reference_builder'

    class ClassificationReference
      attr_reader :ifc_classification_reference

      def initialize(ifc_model, classification, classification_value, identification=nil, location=nil)
        @ifc = BimTools::IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @classification = classification
        @ifc_classification_reference = create_ifc_classification_reference(classification_value, identification, location)
      end

      def add_ifc_entity(ifc_entity)
        @relatedobjects.add(ifc_entity)
      end

      private

      def create_ifc_classification_reference(name = nil, identification = nil, location=nil)
        @ifc_classification_reference = IfcClassificationReferenceBuilder.build(@ifc_model) do |builder|
          builder.set_location(location) if location
          builder.set_referencedsource(@classification.get_ifc_classification)
          builder.set_identification(identification) if identification
          builder.set_name(name) if name
        end
        rel = @ifc::IfcRelAssociatesClassification.new(@ifc_model)
        rel.relatedobjects = BimTools::IfcManager::Ifc_Set.new
        rel.relatingclassification = @ifc_classification_reference
        @relatedobjects = rel.relatedobjects
        @ifc_classification_reference.ifc_rel_associates_classification = rel
      end
    end
  end
end
