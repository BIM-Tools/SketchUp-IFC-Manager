# frozen_string_literal: true

#  ifc_owner_history_builder.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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
require_relative 'ifc_person_builder'

module BimTools
  module IfcManager
    class IfcOwnerHistoryBuilder
      attr_reader :ifc_owner_history

      # Builds an instance of IfcOwnerHistory and adds it to the provided IFC model.
      #
      # @param ifc_model [Object] The IFC model to add the IfcOwnerHistory to.
      # @yield [builder] The builder object.
      # @yieldparam builder [IfcOwnerHistoryBuilder] The builder object.
      # @return [Object] The built IfcOwnerHistory object.
      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)
        builder.ifc_owner_history
      end

      # Initializes a new instance of IfcOwnerHistoryBuilder.
      #
      # @param ifc_model [Object] The IFC model.
      def initialize(ifc_model)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_owner_history = @ifc::IfcOwnerHistory.new(@ifc_model)
      end

      # Sets the owning user of the IfcOwnerHistory.
      #
      # @param user [Object] The owning user.
      def owning_user=(user)
        @ifc_owner_history.owninguser = user
      end

      # Sets the state of the IfcOwnerHistory.
      #
      # @param state [Object] The state.
      def state=(state)
        @ifc_owner_history.state = state
      end

      # Sets the change action of the IfcOwnerHistory.
      #
      # @param action [Object] The change action.
      def change_action=(action)
        @ifc_owner_history.changeaction = action
      end

      # Sets the last modified date of the IfcOwnerHistory.
      #
      # @param date [Object] The last modified date.
      def last_modified_date=(date)
        @ifc_owner_history.lastmodifieddate = date.to_i.to_s
      end

      # Sets the last modifying user of the IfcOwnerHistory.
      #
      # @param user [Object] The last modifying user.
      def last_modifying_user=(user)
        @ifc_owner_history.lastmodifyinguser = user
      end

      # Sets the last modifying application of the IfcOwnerHistory.
      #
      # @param app [Object] The last modifying application.
      def last_modifying_application=(app)
        @ifc_owner_history.lastmodifyingapplication = app
      end

      # Sets the creation date of the IfcOwnerHistory.
      #
      # @param date [Object] The creation date.
      def creation_date=(date)
        @ifc_owner_history.creationdate = date.to_i.to_s
      end

      # Sets the owning user of the IfcOwnerHistory from the SketchUp model.
      #
      # @param su_model [Object] The SketchUp model.
      def owning_user_from_model(su_model)
        owninguser = @ifc::IfcPersonAndOrganization.new(@ifc_model)
        owninguser.theperson = IfcPersonBuilder.build(@ifc_model) do |person_builder|
          person_builder.person_data_from_su_model(su_model)
        end
        owninguser.theorganization = @ifc::IfcOrganization.new(@ifc_model)
        owninguser.theorganization.name = Types::IfcLabel.new(@ifc_model, '')
        @ifc_owner_history.owninguser = owninguser
        @ifc_owner_history.lastmodifyinguser = owninguser
      end

      # Sets the owning application of the IfcOwnerHistory.
      #
      # @param version [String] The version of the owning application.
      # @param fullname [String] The full name of the owning application.
      # @param identifier [String] The identifier of the owning application.
      def owning_application(version, fullname, identifier)
        owningapplication = @ifc::IfcApplication.new(@ifc_model)
        applicationdeveloper = @ifc::IfcOrganization.new(@ifc_model)
        applicationdeveloper.name = Types::IfcLabel.new(@ifc_model, 'BIM-Tools')
        owningapplication.applicationdeveloper = applicationdeveloper
        owningapplication.version = Types::IfcLabel.new(@ifc_model, version)
        owningapplication.applicationfullname = Types::IfcLabel.new(@ifc_model, fullname)
        owningapplication.applicationidentifier = Types::IfcIdentifier.new(@ifc_model, identifier)
        @ifc_owner_history.owningapplication = owningapplication
        @ifc_owner_history.lastmodifyingapplication = owningapplication
      end
    end
  end
end
