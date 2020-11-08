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

module BimTools
  module IfcManager
    module PropertiesWindow      
      class HtmlSelectMaterials < HtmlSelect
        def set_options(extra=nil)
          @options = Sketchup.active_model.materials.map{ |x| x.name}

          # Add position for default material
          @options.prepend("Default")

          # When multiple items are selected add "..."
          if extra
            @options = @options.prepend(extra)
          end
          
          @default_index = @options.find_index("Default")

          json = @options.map{ |i| {:id => @options.find_index(i),:text => i} }.to_json

          @js =  "      $('##{@id}').select2({\n        data: #{json}\n      })\n"
          @js << "$('#add_#{@id}').click(function() {sketchup.add_#{@id}()});"
          @onchange = "$('##{@id}').on('select2:select', function (e) { sketchup.#{@id}(e.params.data.text)});"
        end
        def set_value()
          material_selection = []
          Sketchup.active_model.selection.each do |ent|
            if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
              unless material_selection.include? ent.material
                material_selection << ent.material
              end
            end
          end
          if material_selection.length == 1
            if material_selection[0]
              @value = material_selection[0].name
            else
              @value = @default_index
            end
          else
            set_options("...")
            @value = 0
          end
        end
        def add_save_command(dialog)
          dialog.add_action_callback(@id) { |action_context, value|
            model = Sketchup.active_model
            materials = model.materials
            if value == "..."
            elsif value == "Default"
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
            PropertiesWindow::set_html()
          }
        end
        def html(selection)
          set_options()
          set_value()
          super
        end
      end # class HtmlSelectMaterials
    end # module PropertiesWindow
  end # module IfcManager
end # module BimTools