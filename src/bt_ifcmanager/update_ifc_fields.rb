#  update_ifc_fields.rb
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

module BimTools::IfcManager

  # Helper method that sets the IFC entity name for given ComponentDefinition
  def set_ifc_entity_definition_name(model, definition, name)
    ifc_version = Settings.ifc_version
    ifc_type = definition.get_attribute 'AppliedSchemaTypes', ifc_version
    if ifc_type
      path = [ifc_version, ifc_type.to_s, 'Name', 'IfcLabel']
      
      # overwrite the IFC label for name with the component name
      definition.set_classification_value(path, definition.name) # (?) first check if IFC type had a name attribute?
    end
  end

  # Helper method that sets the IFC entity name for given ComponentInstance
  def set_ifc_entity_name(model, instance, name)
    instance.name = name
    definition = instance.definition
    definition.name = model.definitions.unique_name(name)
    set_ifc_entity_definition_name(model, definition, name)
  end
  
  # This method updates all IFC name fields with the component definition name
  def update_ifc_fields( model )
    ifc_version = Settings.ifc_version
    
    # check if IFC classifications are loaded
    if ifc_version && model.classifications[ifc_version]
    
      # update every component definition in the model
      definitions = model.definitions
      definition_count = definitions.length
      i = 0
      while i < definition_count
        set_ifc_entity_definition_name(model, definitions[i], name.downcase)
        i += 1
      end
    end
  end
end