# frozen_string_literal: true

#  IfcRelDefinesByType_su.rb
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
  module IfcRelDefinesByType_su
    def self.required_attributes(ifc_version)
      # In IFC2X3, the attribute 'RelatedObjects' is part of its parent class 'IfcRelDecomposes'.
      return [] if ifc_version == 'IFC 2x3'

      [:RelatedObjects]
    end
  end
end
