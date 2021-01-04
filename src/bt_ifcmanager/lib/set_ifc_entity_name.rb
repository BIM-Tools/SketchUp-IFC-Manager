#  set_ifc_entity_name.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
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

module BimTools::IfcManager

  # Helper method that sets the IFC entity name for all relevant fields
  #
  # @param [Sketchup::Layer] or [Sketchup::LayerFolder] layer
  # @return [true] if layer is visible
  def set_ifc_entity_name(model, instance, name)
    instance.name = name
    instance.definition.name = model.definitions.unique_name(name)
    ifc_type = instance.definition.get_attribute("AppliedSchemaTypes", "IFC 2x3")
    if ifc_type
      path = ["IFC 2x3", ifc_type, "Name", "IfcLabel"]
      instance.definition.set_classification_value(path, name)
    end
  end
end