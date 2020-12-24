#  select_layers.rb
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
#
#
# select2 for layers

require 'json'

module BimTools::IfcManager
  module PropertiesWindow      
    class HtmlSelectLayers < HtmlSelect

      def initialize(dialog, name)
        super(dialog, name)          
        @button = true
      end

      def set_options(extra=false)
        layers = Sketchup.active_model.layers.map{ |x| x.name}

        # Rename layers to tags for SU 20+
        unless Sketchup.version_number < 2000000000
          if index = layers.index("Layer0")
            layers[index] = "Untagged"
          end
        end
        
        self.options=layers
        super(extra)
      end

      def set_value()
        selection = Set.new()
        Sketchup.active_model.selection.each do |ent|
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            if ent.layer.name != "Layer0"
              selection.add(ent.layer.name)
            else
              selection.add(0)
            end
          end
        end
        set_value_from_list(selection.to_a)
      end
      
      def html(selection)
        set_options()
        set_value()
        super
      end

      # def update(selection)
      #   set_options()
      #   super(selection)
      # end

      def set_callback()

        # Add save callback
        @dialog.add_action_callback(@id) { |action_context, value|
          model = Sketchup.active_model
          layers = model.layers
          if value == "..."
          elsif value == "Untagged" || value == "-"
            model.selection.each do |ent|
              ent.layer = "Layer0"
            end
          elsif layers[value]
            model.selection.each do |ent|
              ent.layer = value
            end
          else
            notification = UI::Notification.new(IFCMANAGER_EXTENSION, "No layer with name: " + value)
            notification.show
          end
          PropertiesWindow::update()
        }

        # Add button callback
        @dialog.add_action_callback("add_" + @id) { |action_context|
          input = UI.inputbox(["Name:"], [""], "Create tag...")
          if input
            
            # make sure the input is never empty to get a proper layer name
            if input[0] == ""
              input[0] = "Tag"
            end

            model = Sketchup.active_model
            new_layer = model.layers.add(input[0].downcase)
            model.selection.each do |entity|
              entity.layer = new_layer.name
            end
            PropertiesWindow::set_html()
          end
        }
      end
    end
  end
end