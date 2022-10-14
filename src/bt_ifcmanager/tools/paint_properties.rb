#       paint_properties.rb
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

# Copy properties from selection to target object

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH, 'update_ifc_fields')
    module PaintProperties
      extend self
      attr_accessor :name

      @name = 'Paint properties'
      @description = 'Copy properties of BIM-Tools elements'
      @cursor_icon = File.join(PLUGIN_PATH_IMAGE, "PaintProperties-cursor#{ICON_LARGE}#{ICON_TYPE}")
      @source = nil
      @cursor_id = nil

      # create cursor
      @cursor_id = UI.create_cursor(@cursor_icon, 4, 3) if File.file?(@cursor_icon) # check if file is really a file

      # add to TOOLBAR
      cmd = UI::Command.new(@description) do
        Sketchup.active_model.select_tool(self)
      end
      cmd.small_icon = File.join(PLUGIN_PATH_IMAGE, "PaintProperties#{ICON_SMALL}#{ICON_TYPE}")
      cmd.large_icon = File.join(PLUGIN_PATH_IMAGE, "PaintProperties#{ICON_LARGE}#{ICON_TYPE}")
      cmd.tooltip = 'Paint properties'
      cmd.status_bar_text = 'Paint BIM-Tools properties'
      IfcManager.toolbar.add_item cmd

      # The activate method is called by SketchUp when the tool is first selected.
      # it is a good place to put most of your initialization
      def activate
        @model = Sketchup.active_model

        reset(nil)

        UI.set_cursor(@cursor_id)

        # if a source object is already selected, use that and skip step 1
        if @model.selection.length == 1 && @source = @model.selection[0]
          @state = 1
          Sketchup.set_status_text 'Select target object', SB_PROMPT
        end
      end

      # deactivate is called when the tool is deactivated because
      # a different tool was selected
      def deactivate(view); end

      # The onLButtonDOwn method is called when the user presses the left mouse button.
      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        bp = ph.best_picked

        # When the user clicks the first time, we switch to getting the
        # second point.  When they click a second time we copy properties
        if @state == 0
          if bp.is_a?(Sketchup::ComponentInstance)
            @model.selection.clear
            @model.selection.add bp
            if @source = bp
              @state = 1
              Sketchup.set_status_text 'Select target object', SB_PROMPT
            end
          end
        elsif bp.is_a?(Sketchup::ComponentInstance)
          # copy properties on second and following clicks
          if target = bp
            clone_properties(@source, target)
          end
        end
        if target.is_a?(Sketchup::ComponentInstance)
          @model.selection.clear
          @model.selection.add target

          # refresh edit window
          if IfcManager::PropertiesWindow.window && IfcManager::PropertiesWindow.window.visible?
            IfcManager::PropertiesWindow.set_html
          end
        end
      end

      # copy all properties from source to target
      def clone_properties(source, target)
        # start undo section
        @model.start_operation('Paint properties', disable_ui = true)

        # clone basic Drawingelement properties
        # skip 'hidden' and 'visible'
        target.material = source.material
        target.layer = source.layer
        target.casts_shadows = source.casts_shadows?
        target.receives_shadows = source.receives_shadows?

        # clone ComponentInstance properties
        target.name = source.name

        # clone ComponentDefinition properties
        # skip 'behavior' and 'visible'
        # also skip definition name --> must be unique!
        target.definition.description = source.definition.description
        target.definition.name = @model.definitions.unique_name(source.definition.name)

        # clone attribute dictionaries

        # clear existing target definition attributes
        target_dicts = target.definition.attribute_dictionaries
        unless target_dicts.nil?
          target.definition.attribute_dictionaries.each do |dict|
            target_dicts.delete dict unless dict.name == 'GSU_ContributorsInfo' || dict.name == 'dynamic_attributes'
          end
        end

        # copy attributes
        clone_attributes(source.definition, target.definition)

        # Fix IFC name property
        BimTools::IfcManager.set_ifc_entity_name(@model, target, target.definition.name)

        @model.commit_operation # End of operation/undo section
        @model.active_view.refresh # Refresh model
      end

      # Reset the tool back to its initial state
      def reset(view)
        # This variable keeps track of which point we are currently getting
        @state = 0

        # Display a prompt on the status bar
        Sketchup.set_status_text 'Select source object', SB_PROMPT

        # clear source object
        @source = nil

        view.tooltip = nil if view
      end

      def onSetCursor
        UI.set_cursor(@cursor_id)
      end

      # recursively copy all attribute dictionaries from source to target entity
      def clone_attributes(source, target)
        unless source.attribute_dictionaries.nil? # stop if there are no child dictionaries
          source.attribute_dictionaries.each do |source_dict|
            if source_dict.name == 'GSU_ContributorsInfo' || source_dict.name == 'dynamic_attributes'
              next
            end # Not allowed to create Contributors attribute. & Don't mess up dynamic components --> skip

            source_dict.each do |key, value|
              target.set_attribute source_dict.name, key, value # create the same dictionary in target
            end

            target_dict = target.attribute_dictionary(source_dict.name, true)
            if target_dict
              clone_attributes(source_dict, target_dict) # recursively check all possible child dictionaries
            else
              puts "Unable to copy: #{source_dict.name}"
            end
          end
        end
      end
    end
  end
end
