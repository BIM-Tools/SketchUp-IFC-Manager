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

require 'json'

module BimTools::IfcManager
  module PropertiesWindow      
    class HtmlSelectMaterials < HtmlSelect

      def initialize(dialog, name)
        super(dialog, name)          
        @button = true
      end

      def set_options(extra=nil)
        materials = Sketchup.active_model.materials.map{ |x| x.name}

        # Add default material
        options_template = [{:id => "-", :text => "Default"}]

        self.set_js_options(materials,options_template)
        super(extra)
      end
      
      def set_value()
        selection = Set.new()
        Sketchup.active_model.selection.each do |ent|
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            if ent.material
              selection.add(ent.material.name)
            else
              selection.add("Default")
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
          materials = model.materials
          if value == "..."
          elsif value == "Default" || value == "-"
            model.selection.each do |ent|
              ent.material = nil
            end
          elsif materials[value]
            model.selection.each do |ent|
              ent.material = value
            end
          else
            notification = UI::Notification.new(IFCMANAGER_EXTENSION, "No material with name: " + value)
            notification.show
          end
          PropertiesWindow::update()
        }

        # Add button callback
        @dialog.add_action_callback("add_" + @id) { |action_context|
          input = UI.inputbox(["Name:"], [""], "Create material...")
          if input
          
            # make sure the input is never empty to get a proper material name
            if input[0] == ""
              input[0] = "Material"
            end
            
            model = Sketchup.active_model
            new_material = model.materials.add(input[0].downcase)
            new_material.color = [255, 255, 255]
            model.selection.each do |entity|
              entity.material = new_material.name
            end
            index = @index_max
            @index_max += 1
            self.dialog.execute_script("var newMaterialOption = new Option('#{new_material.name}', '#{index}', false, true);\n$('##{@id}').append(newMaterialOption).trigger('change');\n")
          end
        }
      end
    end
  end
end