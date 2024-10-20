# frozen_string_literal: true

#  IfcPile_su.rb
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
  module IfcPile_su
    @constructiontype = nil
    attr_reader :constructiontype

    def constructiontype=(value)
      puts BimTools::IfcManager::Settings.ifc_version_compact
      if BimTools::IfcManager::Settings.ifc_version_compact == 'IFC2X3'
        @constructiontype = value.value.to_sym
      else
        puts 'ConstructionType attribute deprecated'
      end
    end
  end
end
