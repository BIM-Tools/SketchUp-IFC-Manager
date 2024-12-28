# frozen_string_literal: true

#  IfcObjectDefinition_su.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcObjectDefinition_su
    attr_accessor :decomposes, :default_decomposing_objects

    def initialize(ifc_model, sketchup)
      super
      @ifc_module = ifc_model.ifc_module
      @ifc_model = ifc_model

      # keep track of default decomposing objects
      # which are added when a valid spatial parent is not present in the spatial hierarchy
      @default_decomposing_objects = []
    end

    # Add an element for which this element is the spatial container
    # Like a wall thats contained in a building
    #
    def add_contained_element(object)
      unless @contains_elements
        @contains_elements = @ifc_module::IfcRelContainedInSpatialStructure.new(@ifc_model)
        @contains_elements.relatingstructure = self
        # else
        #   puts 'ERROR: object does not respond to relatingstructure'
        # end
        @contains_elements.relatedelements = IfcManager::Types::Set.new
      end
      @contains_elements.relatedelements.add(object)
    end

    def add_default_decomposing_object(ifc_entity)
      @default_decomposing_objects << ifc_entity
    end

    def default_decomposing_object_of_type(type)
      @default_decomposing_objects.find { |ifc_entity| ifc_entity.is_a?(type) }
    end

    # Add an object from which this element is decomposed
    # Like a building is decomposed into multiple buildingstoreys
    # Or a curtainwall is decomposed into muliple members/plates
    #
    def add_related_object(object)
      unless @decomposes
        @decomposes = @ifc_module::IfcRelAggregates.new(@ifc_model)
        @decomposes.name = IfcManager::Types::IfcLabel.new(@ifc_model, "#{name.value} container") if name
        # if @decomposes.respond_to?(:relatingobject)
        @decomposes.relatingobject = self
        # else
        #   puts 'ERROR: object does not respond to relatingobject'
        # end
        @decomposes.relatedobjects = IfcManager::Types::Set.new
      end
      @decomposes.relatedobjects.add(object)
    end
  end
end
