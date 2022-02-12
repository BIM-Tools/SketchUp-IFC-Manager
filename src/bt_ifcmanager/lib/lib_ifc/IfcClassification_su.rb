#  IfcClassification_su.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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
  module IfcClassification_su
    attr_accessor :ifc_classification_references

    DEFAULT_SOURCE_VALUE = 'unknown'
    DEFAULT_EDITION_VALUE = 'unknown'
    def initialize(ifc_model, sketchup = nil)
      # key must be reference name, value the IfcClassificationReference object
      @ifc_classification_references = {}
      super
    end

    def step
      # Workaround for mandatory values in IFC2x3
      if BimTools::IfcManager::Settings.ifc_version == 'IFC 2x3'
        @source ||= BimTools::IfcManager::IfcLabel.new(@ifc_model, DEFAULT_SOURCE_VALUE)
        @edition ||= BimTools::IfcManager::IfcLabel.new(@ifc_model, DEFAULT_EDITION_VALUE)
      end
      super
    end
  end
end
