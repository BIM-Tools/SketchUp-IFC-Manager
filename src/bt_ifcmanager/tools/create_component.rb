#       create_component.rb
#
#       Copyright (C) 2017 Jan Brouwer <jan@brewsky.nl>
#
#       This program is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 3 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Create component from selected entities

module BimTools
 module IfcManager
  require File.join(PLUGIN_PATH, 'update_ifc_fields')
  module CreateComponent
    extend self
    attr_accessor :name

    @name = 'Create component'
    @description = 'Create component from selected entities'

    def add_component_option( ifc_type, name, objecttype=nil )
      UI.add_context_menu_handler do |context_menu|
        selection = Sketchup.active_model.selection
        unless selection.empty?
          context_menu.add_item("Create #{name}") {
            CreateComponent.activate( ifc_type, name, objecttype )
          }
        end
      end
    end

    # Add the following create new component options to the context menu
    add_component_option( 'IfcBuildingElementProxy', 'Building Element' )
    add_component_option( 'IfcBuildingStorey', 'Building Storey' )
    add_component_option( 'IfcBuilding', 'Building' )
    add_component_option( 'IfcSite', 'Site' )

    # The activate method is called by SketchUp when the tool is first selected.
    # it is a good place to put most of your initialization
    def activate( ifc_type, name, objecttype=nil )
      model = Sketchup.active_model
      entities = model.active_entities
      selection = model.selection

      model.start_operation('Create IFC Component', true)

      # create temporary group
      group = entities.add_group( selection )

      # convert group to component instance
      instance = group.to_component

      # set IFC type
      instance.definition.add_classification(IfcManager::Settings.ifc_version, ifc_type)

      # Set name in definition, instance and ifc properties
      IfcManager::set_ifc_entity_name(model, instance, name.downcase)

      # set group as selected entity
      selection.clear
      selection.add( instance )

      model.commit_operation

      # open edit window
      if IfcManager::PropertiesWindow.window && IfcManager::PropertiesWindow.window.visible?
        IfcManager::PropertiesWindow.set_html
      else
        IfcManager::PropertiesWindow.show
      end
      return instance
    end
  end
 end
end
