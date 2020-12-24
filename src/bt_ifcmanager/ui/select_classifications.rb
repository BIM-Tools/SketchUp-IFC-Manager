#  select_materials.rb
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
# select2 for materials

module BimTools::IfcManager
  module PropertiesWindow      
    class HtmlSelectClassifications < HtmlSelect
      def set_value()
        selection = Set.new()
        Sketchup.active_model.selection.each do |ent|
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            selection.add(ent.definition.get_attribute("AppliedSchemaTypes", @name))
          end
        end
        set_value_from_list(selection.to_a)
      end
      
      def html(selection)
        set_options()
        set_value()
        super
      end

      def set_callback()

        # Add save callback
        model = Sketchup.active_model
        @dialog.add_action_callback(@id) { |action_context, value|
          if model.classifications[@name]
            model.selection.each do |ent|
              if(ent.is_a? Sketchup::ComponentInstance) || (ent.is_a? Sketchup::Group)
                if value == "-"
                  old_value = ent.definition.get_attribute("AppliedSchemaTypes", @name)
                  ent.definition.remove_classification(@name, old_value)
                else
                  ent.definition.add_classification(@name, value)
                end
              end
            end
          else
            notification = UI::Notification.new(IFCMANAGER_EXTENSION, "No classification with name: " + @name)
            notification.show
          end
          PropertiesWindow::update()
        }
      end
    end
  end
end