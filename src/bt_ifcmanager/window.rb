# frozen_string_literal: true

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
# IFC properties window

require 'yaml'

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH, 'observers')
    require File.join(PLUGIN_PATH_UI, 'html')
    require File.join(PLUGIN_PATH_UI, 'title')
    require File.join(PLUGIN_PATH_UI, 'input_name')
    require File.join(PLUGIN_PATH_UI, 'select')
    require File.join(PLUGIN_PATH_UI, 'select_classifications')
    require File.join(PLUGIN_PATH_UI, 'select_materials')
    require File.join(PLUGIN_PATH_UI, 'select_layers')

    module PropertiesWindow
      attr_reader :window, :ready

      extend self
      @window = nil
      @visible = false
      @ready = false
      @form_elements = []
      @window_options = {
        dialog_title: 'Edit IFC properties',
        preferences_key: 'BimTools-IfcManager-PropertiesWindow',
        width: 400,
        height: 400,
        resizable: true
      }
      @observers = BimTools::IfcManager::Observers.new

      # Create the HtmlDialog window and form elements
      # needs to be recreated only when settings change
      def create
        initialize_window
        add_title
        add_classification_selects
        add_form_elements
      end

      # Close the HtmlDialog window
      def close
        @observers.stop
        @window.close if visible?
      end

      # Show the HtmlDialog window
      def show
        create unless @window
        @observers.start
        set_html
        @window.show unless visible?
      end

      # Reload the HtmlDialog window
      def reload
        close if visible?
        show
      end

      # Check if the window is visible
      def visible?
        @window && @window.visible? || false
      end

      # Toggle the visibility of the HtmlDialog window
      def toggle
        visible? ? close : show
      end

      # Update form elements based on the current selection
      def update
        selection = Sketchup.active_model.selection
        ifc_able = ifc_classifiable?(selection)

        @form_elements.each do |form_element|
          form_element.update(selection)
          if ifc_able
            form_element.show
          else
            form_element.hide
          end
        end
      end

      private

      # Initialize the HtmlDialog window
      def initialize_window
        @form_elements = []
        @window = UI::HtmlDialog.new(@window_options)
        @window.set_on_closed { @observers.stop }
      end

      # Add the title element to the form
      def add_title
        @form_elements << Title.new(@window)
      end

      # Add classification dropdowns to the form
      def add_classification_selects
        classification_list = build_classification_list
        classification_list.each_pair do |classification_file, active|
          next unless active && valid_classification?(classification_file)

          classification = BimTools::IfcManager::Settings.filters[classification_file]
          classification_name = classification.name
          ui_classification = HtmlSelectClassifications.new(@window, classification_name)

          options_template = [{ id: '-', text: '-' }]
          options = load_classification_options(classification_name, classification)

          ui_classification.set_js_options(options, options_template)
          @form_elements << ui_classification
        end
      end

      # Add other form elements (e.g., input name, materials, layers)
      def add_form_elements
        @form_elements << HtmlInputName.new(@window)
        @form_elements << HtmlSelectMaterials.new(@window, 'Material')
        @form_elements << HtmlSelectLayers.new(@window, 'Tag/Layer')
      end

      # Refresh the entire window contents
      def set_html
        selection = Sketchup.active_model.selection
        ifc_able = ifc_classifiable?(selection)

        html = html_header
        javascript = +''

        @form_elements.each do |form_element|
          form_element.hide unless ifc_able
          html << form_element.html(selection)
          javascript << form_element.js
          javascript << form_element.onchange
        end

        html << html_footer(javascript)
        @window.set_html(html)
        set_callbacks
      end

      # Set callbacks for form elements
      def set_callbacks
        @form_elements.each(&:set_callback)
      end

      # Build the classification list from settings
      def build_classification_list
        { Settings.ifc_classification => true }.merge(Settings.active_classifications)
      end

      # Check if a classification is valid
      def valid_classification?(classification_file)
        BimTools::IfcManager::Settings.filters.key?(classification_file)
      end

      # Load classification options from a YAML file or fallback to default options
      def load_classification_options(classification_name, classification)
        yml_path = File.join(PLUGIN_PATH, 'classifications', "#{classification_name}.yml")
        if File.file?(yml_path)
          options = YAML.load(File.read(yml_path))
          sanitize_options(options)
        else
          sanitize_options(classification.get_skc_options)
        end
      end

      # Sanitize options to ensure proper UTF-8 encoding
      def sanitize_options(options)
        options.map do |opt|
          begin
            opt.force_encoding('UTF-8')
          rescue StandardError
            '-'
          end
        end
      end

      # Check if the selection contains IFC classifiable entities
      def ifc_classifiable?(selection)
        selection.any? { |ent| ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group) }
      end
    end
  end
end
