#  IfcProject.rb
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
  module IfcRoot_su
    def initialize(ifc_model, sketchup=nil)
      require_relative('IfcGloballyUniqueId.rb')
      @globalid = IfcManager::new_guid
      @ownerhistory = ifc_model.owner_history
    end # def sketchup
  end # module IfcRoot_su
end # module BimTools