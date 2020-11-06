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
          i = 0
          json_options = []
          if extra
            json_options << {
              :id => extra,
              :text => extra
            }
          end
          @options = []
          Sketchup.active_model.layers.each do |layer|
            @options << layer.name
          end
          while i < @options.length do
            json_options << {
              :id => i,
              :text => @options[i]
            }
            i += 1
          end
          json = json_options.to_json
          @js =  "      $('##{@id}').select2({\n        data: #{json}\n      })\n"
          @js << "$('#add_#{@id}').click(function() {sketchup.add_#{@id}()});"
          @onchange = "$('##{@id}').on('select2:select', function (e) { sketchup.#{@id}(e.params.data.text)});"
        end
        def set_value()
          selection = []
          Sketchup.active_model.selection.each do |ent|
            if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
              unless selection.include? ent.layer
                selection << ent.layer
              end
            end
          end
          if selection.length == 1
            if selection[0]
              @value = selection[0].name
            end
          else
            set_options("...")
            @value = "..."
          end
        end
        def add_save_command(dialog)
          dialog.add_action_callback(@id) { |action_context, value|
            model = Sketchup.active_model
            layers = model.layers
            if value == "..."
            elsif layers[value]
              model.selection.each do |ent|
                ent.layer = value
              end
            else
              notification = UI::Notification.new(IFCMANAGER_EXTENSION, "No layer with name: " + value)
              notification.show
            end
            # @value = value
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