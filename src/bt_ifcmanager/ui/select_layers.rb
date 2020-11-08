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

module BimTools
  module IfcManager
    module PropertiesWindow      
      class HtmlSelectLayers < HtmlSelect
        def set_options(extra=nil)
          @options = Sketchup.active_model.layers.map{ |x| x.name}

          # Rename layers to tags for SU 20+
          unless Sketchup.version_number < 2000000000
            if index = @options.index("Layer0")
              @options[index] = "Untagged"
            end
          end

          # When multiple items are selected add "..."
          if extra
            @options = @options.prepend(extra)
          end
          json = @options.map{ |i| {:id => @options.find_index(i),:text => i} }.to_json
          @js =  "      $('##{@id}').select2({\n        data: #{json}\n      })\n"
          @js << "$('#add_#{@id}').click(function() {sketchup.add_#{@id}()});"
          @onchange = "$('##{@id}').on('select2:select', function (e) { sketchup.#{@id}(e.params.data.text)});"
        end
        def set_value()
          layer_selection = []
          Sketchup.active_model.selection.each do |ent|
            if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
              unless layer_selection.include? ent.layer
                layer_selection << ent.layer
              end
            end
          end
          if layer_selection.length == 1
            if (layer_selection[0]) && (layer_selection[0].name != "Layer0")
              @value = layer_selection[0].name
            else
              @value = "Untagged"
            end
          else
            set_options("...")
            @value = 0
          end
        end
        def add_save_command(dialog)
          dialog.add_action_callback(@id) { |action_context, value|
            model = Sketchup.active_model
            layers = model.layers
            if value == "..."
            elsif value == "Untagged"
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
            PropertiesWindow::set_html()
          }
        end
        def html(selection)
          set_options()
          set_value()
          super
        end
      end # class HtmlSelectLayers
    end # module PropertiesWindow
  end # module IfcManager
end # module BimTools