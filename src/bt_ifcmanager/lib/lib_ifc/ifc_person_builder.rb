# frozen_string_literal: true

#  ifc_person_builder.rb
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

module BimTools
  module IfcManager
    class IfcPersonBuilder
      attr_reader :ifc_person

      # Builds an IFC person and adds it to the provided IFC model.
      #
      # @param ifc_model [IFCModel] The IFC model to add the person to.
      # @yield [builder] The builder object to configure the person.
      # @yieldparam builder [IFCPersonBuilder] The builder object to configure the person.
      # @return [IFCPerson] The built IFC person.
      def self.build(ifc_model)
        builder = new(ifc_model)
        yield(builder)

        # According to the formal propositions in the ReferenceView MVD, at least one of the identification, family name, or given name must be provided.
        # Set the family name to an empty string if no identification, family name, or given name has been provided
        if builder._identification?.nil? && builder.ifc_person.familyname.nil? && builder.ifc_person.givenname.nil?
          builder.ifc_person.familyname = IfcManager::Types::IfcLabel.new(ifc_model, '')
        end

        builder.ifc_person
      end

      # Initializes a new instance of the IfcPersonBuilder class.
      #
      # @param ifc_model [IFCModel] The IFC model to add the person to.
      # @return [IfcPersonBuilder] A new instance of the IfcPersonBuilder class.
      def initialize(ifc_model)
        @ifc = IfcManager::Settings.ifc_module
        @ifc_model = ifc_model
        @ifc_person = @ifc::IfcPerson.new(@ifc_model)
      end

      # Sets the user identification for the IFC person.
      #
      # @param identification [String] The user identification to set.
      # @return [void]
      def identification=(identification)
        return unless identification

        _identification = identification
      end

      # Sets the family name of the IFC person.
      #
      # @param name [String] The family name to set.
      # @return [void]
      def family_name=(name)
        return unless @ifc_person.respond_to?(:familyname) && name

        @ifc_person.familyname = IfcManager::Types::IfcLabel.new(@ifc_model, name)
      end

      # Sets the given name of the IFC person.
      #
      # @param name [String] The given name to set.
      # @return [void]
      def given_name=(name)
        return unless @ifc_person.respond_to?(:givenname) && name

        @ifc_person.givenname = IfcManager::Types::IfcLabel.new(@ifc_model, name)
      end

      # Sets the middle names of the IFC person.
      #
      # @param names [Array<String>] The middle names to set.
      # @return [void]
      def middle_names=(names)
        return unless @ifc_person.respond_to?(:middlenames) && names

        @ifc_person.middlenames = names.map { |name| IfcManager::Types::IfcLabel.new(@ifc_model, name) }
      end

      # Sets the prefix titles of the IFC person.
      #
      # @param titles [Array<String>] The prefix titles to set.
      # @return [void]
      def prefix_titles=(titles)
        return unless @ifc_person.respond_to?(:prefixtitles) && titles

        @ifc_person.prefixtitles = titles.map { |title| IfcManager::Types::IfcLabel.new(@ifc_model, title) }
      end

      # Sets the suffix titles of the IFC person.
      #
      # @param titles [Array<String>] The suffix titles to set.
      # @return [void]
      def suffix_titles=(titles)
        return unless @ifc_person.respond_to?(:suffixtitles) && titles

        @ifc_person.suffixtitles = titles.map { |title| IfcManager::Types::IfcLabel.new(@ifc_model, title) }
      end

      # Sets the person data from a SketchUp model.
      #
      # @param su_model [SketchUpModel] The SketchUp model from which to retrieve the person data.
      # @return [void]
      def person_data_from_su_model(su_model)
        user_ids = su_model.get_attribute('GSU_ContributorsInfo', 'UserIdsKey')
        self._identification = user_ids.first if user_ids && user_ids.any?

        nicknames = su_model.get_attribute('GSU_ContributorsInfo', 'NicknamesKey')
        self.family_name = nicknames.first if nicknames && nicknames.any?
      end

      # Returns the identification of the IFC person. Taking into account the different IFC versions
      #
      # Returns nil if neither method is available.
      def _identification?
        if @ifc_person.respond_to?(:identification)
          @ifc_person.identification
        elsif @ifc_person.respond_to?(:id)
          @ifc_person.id
        end
      end

      # Sets the identification of the IFC person. Taking into account the different IFC versions
      #
      # Parameters:
      # - identification: The identification value to be set.
      #
      # Returns: None
      def _identification=(identification)
        if @ifc_person.respond_to?(:identification)
          @ifc_person.identification = IfcManager::Types::IfcIdentifier.new(@ifc_model, identification)
        elsif @ifc_person.respond_to?(:id)
          @ifc_person.id = IfcManager::Types::IfcIdentifier.new(@ifc_model, identification)
        end
      end
    end
  end
end
