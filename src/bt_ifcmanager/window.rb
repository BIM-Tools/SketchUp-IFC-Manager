#  window.rb
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

require 'yaml'

module BimTools
 module IfcManager
  require File.join(PLUGIN_PATH, 'observers.rb')
  require File.join(PLUGIN_PATH_UI, 'html.rb')
  require File.join(PLUGIN_PATH_UI, 'title.rb')
  require File.join(PLUGIN_PATH_UI, 'input_text.rb')
  require File.join(PLUGIN_PATH_UI, 'select.rb')
  require File.join(PLUGIN_PATH_UI, 'select_classifications.rb')
  require File.join(PLUGIN_PATH_UI, 'select_materials.rb')
  require File.join(PLUGIN_PATH_UI, 'select_layers.rb')

  module PropertiesWindow
    attr_reader :window, :ready
    extend self
    @window = false
    @visible = false
    @ready = false
    @form_elements = Array.new
    @window_options = {
      :dialog_title    => 'Edit IFC properties',
      :preferences_key => 'BimTools-IfcManager-PropertiesWindow',
      :width           => 400,
      :height          => 400,
      :resizable       => true
    }
  
    # create observers
    @observers = IfcManager::Observers.new()

    # create Sketchup HtmlDialog window
    def create()
      model = Sketchup.active_model
      selection = model.selection
      @form_elements = Array.new
      @window = UI::HtmlDialog.new( @window_options )
      @window.set_on_closed {
        @observers.stop
      }

      # Add title showing selected items
      @form_elements << Title.new()

      # Add html select for classifications
      classification_list = {"IFC 2x3" => true}.merge!(Settings.classifications)
      classification_list.each_pair do | classification_name, active |
        if active
          classification = HtmlSelectClassifications.new(@window, classification_name)
          classification.options = YAML.load_file(File.join(PLUGIN_PATH, "classifications", classification_name + ".yml"))
          @form_elements << classification
        end
      end

      # Add html text input for definition name
      name = HtmlInputText.new(@window, "Name")
      @window.add_action_callback(name.id) { |action_context, value|
        Sketchup.active_model.selection.each do |ent|
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            ent.definition.name = value
          end
        end
        PropertiesWindow::set_html()
      }
      name.define_singleton_method(:set_value) do
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
            @value = selection[0].name
          end
        else
          @value = "..."
        end
      end
      @form_elements << name

      materials = HtmlSelectMaterials.new(@window, "Material")
      @form_elements << materials
      @window.add_action_callback("add_" + materials.id) { |action_context|
        input = UI.inputbox(["Name:"], [""], "Create material...")
        if input
        
          # make sure the input is never empty to get a proper material name
          if input[0] == ""
            input[0] = "Material"
          end
          
          new_material = model.materials.add(input[0].downcase)
          new_material.color = [255, 255, 255]
          model.selection.each do |entity|
            entity.material = new_material.name
          end
          PropertiesWindow::set_html()
        end
      }
      materials.add_button()
      layers = HtmlSelectLayers.new(@window, "Tag/Layer")
      @form_elements << layers
      @window.add_action_callback("add_" + layers.id) { |action_context|
        input = UI.inputbox(["Name:"], [""], "Create tag...")
        if input
          
          # make sure the input is never empty to get a proper layer name
          if input[0] == ""
            input[0] = "Tag"
          end
          new_layer = Sketchup.active_model.layers.add(input[0].downcase)
          model.selection.each do |entity|
            entity.layer = new_layer.name
          end
          PropertiesWindow::set_html()
        end
      }
      layers.add_button()
    end # def create

    def close
      @observers.stop
      if @window
        @window.close
      end
    end # def close

    # show Sketchup HtmlDialog window
    def show
      @observers.start
      unless @window
        self.create()
      end
      PropertiesWindow::set_html()
      unless @window.visible?
        @window.show
      end
    end # def show

    def toggle
      if @window
        if@window.visible?
          self.close
        else
          self.show
        end
      else
        self.create()
        self.show
      end
    end # def toggle
    
    def set_html()
      model = Sketchup.active_model
      ifc_able = false
      model.selection.each do |ent|
        if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
          ifc_able = true
          break
        end
      end
      if(ifc_able)
        html = html_header()
        @form_elements.each do |form_element|
          html << form_element.html(model.selection)
        end
        js = ""
        @form_elements.each do |form_element|
          js << form_element.js
          js << form_element.onchange
        end
        html << html_footer(js)
      else
        html = html_header()
        html << "<h1>No selection</h1>"
        html << html_footer("")
      end
      @window.set_html(html)
    end # def set_html
  end # module PropertiesWindow
 end # module IfcManager
end # module BimTools