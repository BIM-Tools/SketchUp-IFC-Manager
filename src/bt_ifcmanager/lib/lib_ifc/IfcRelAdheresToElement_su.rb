# frozen_string_literal: true

#  IfcRelAdheresToElement_su.rb
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

module BimTools
  module IfcRelAdheresToElement_su
    def self.required_attributes(_ifc_version)
      [:RelatingElement]
    end

    def ifcx
      return unless @relatingelement && @relatedsurfacefeatures

      @relatedsurfacefeatures.each_with_object({}) do |related_element, h|
        h[unique_key(related_element)] = related_element.globalid.ifcx if related_element.globalid.respond_to?(:ifcx)
      end
    end

    private

    def unique_key(related_object)
      name = related_object.respond_to?(:name) ? related_object.name : nil
      persistent_id =
        if related_object.respond_to?(:globalid) && related_object.globalid && related_object.globalid.respond_to?(:ifcx)
          related_object.globalid.ifcx
        elsif related_object.respond_to?(:su_object) && related_object.su_object && related_object.su_object.respond_to?(:persistent_id)
          related_object.su_object.persistent_id
        end

      key_parts = [name.value, persistent_id].compact

      key_parts.join(' - ')
    end
  end
end
