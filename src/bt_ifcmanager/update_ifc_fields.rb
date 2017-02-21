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

# This method updates all IFC name fields with the component definition name
module BimTools
 module IfcManager
  def update_ifc_fields( model )
    
    # check if IFC classifications are loaded
    if model.classifications['IFC 2x3']
    
      # update every component definition in the model
      model.definitions.each do | entity |
        type = entity.get_attribute 'AppliedSchemaTypes', 'IFC 2x3'
        if type
          path = ['IFC 2x3', type.to_s, 'Name', 'IfcLabel']
          
          # overwrite the IFC label for name with the component name
          entity.set_classification_value(path, entity.name) # (?) does every IFC type in sketchup have a name?
        end
      end
    end
  end # def update_ifc_fields
 end # module IfcManager
end # module BimTools
