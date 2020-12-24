#  input_name.rb
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
# input text name element

module BimTools::IfcManager
  require File.join(PLUGIN_PATH_UI, 'input_text.rb')
  module PropertiesWindow
    class HtmlInputName < HtmlInputText
      def initialize(dialog)
        super(dialog, "Name")
      end
      def set_callback()
        super
        self.dialog.add_action_callback(self.id) { |action_context, value|
          Sketchup.active_model.selection.each do |ent|
            if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
              ent.definition.name = value
            end
          end
          PropertiesWindow::update()
        }
      end
      def set_value()
        selection = []
        Sketchup.active_model.selection.each do |ent|
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            unless selection.include? ent.definition
              selection << ent.definition
            end
          end
        end
        if selection.length == 1
          if selection[0]
            self.value = selection[0].name
          end
        else
          self.value = "..."
        end
      end
    end
  end
end