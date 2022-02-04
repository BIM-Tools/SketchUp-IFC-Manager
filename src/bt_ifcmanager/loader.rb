#  loader.rb
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

# Main loader for IfcManager plugin

# (!) Note: securerandom takes very long to load
require 'securerandom'

module BimTools
  module IfcManager
  
    PLATFORM_IS_OSX     = ( Object::RUBY_PLATFORM =~ /darwin/i ) ? true : false
    PLATFORM_IS_WINDOWS = !PLATFORM_IS_OSX
    
    # set icon file type
    if Sketchup.version_number < 1600000000
      ICON_TYPE = ".png"
      ICON_SMALL = "_small"
      ICON_LARGE = "_large"
    elsif PLATFORM_IS_WINDOWS
      ICON_TYPE = ".svg"
      ICON_SMALL = ""
      ICON_LARGE = ""
    else # OSX
      ICON_TYPE = ".pdf"
      ICON_SMALL = ""
      ICON_LARGE = ""
    end
    
    attr_reader :toolbar
    attr_accessor :export_messages

    extend self

    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    PLUGIN_PATH_CSS = File.join(PLUGIN_PATH, 'css')
    PLUGIN_PATH_LIB = File.join(PLUGIN_PATH, 'lib')
    PLUGIN_PATH_UI = File.join(PLUGIN_PATH, 'ui')
    PLUGIN_PATH_TOOLS = File.join(PLUGIN_PATH, 'tools')
    PLUGIN_PATH_CLASSIFICATIONS = File.join(PLUGIN_PATH, 'classifications')
    
    # Create export message collection
    @export_messages = Array.new

    # Create IfcManager toolbar
    @toolbar = UI::Toolbar.new "IFC Manager"

    # Load settings from yaml file
    require File.join(PLUGIN_PATH, 'settings.rb')
    Settings.load_settings()
    
    require File.join(PLUGIN_PATH, 'window.rb')
    require File.join(PLUGIN_PATH, 'export.rb')
    require File.join(PLUGIN_PATH_TOOLS, 'paint_properties.rb')
    require File.join(PLUGIN_PATH_TOOLS, 'create_component.rb')
    require File.join(PLUGIN_PATH_TOOLS, 'ifc_import.rb')
    
    # add tools to toolbar  
    # Open window button
    btn_ifc_window = UI::Command.new('Show IFC properties') {
      PropertiesWindow.toggle
    }
    btn_ifc_window.small_icon = File.join(PLUGIN_PATH_IMAGE, "IfcEdit#{ICON_SMALL}#{ICON_TYPE}")
    btn_ifc_window.large_icon = File.join(PLUGIN_PATH_IMAGE, "IfcEdit#{ICON_LARGE}#{ICON_TYPE}")
    btn_ifc_window.tooltip = "Show IFC properties"
    btn_ifc_window.status_bar_text = "Edit IFC properties"
    
    # Import IFC file
    btn_ifc_import = UI::Command.new("Import IFC file") {
      ifc_import()
    }
    btn_ifc_import.small_icon = File.join(PLUGIN_PATH_IMAGE, "IfcImport#{ICON_SMALL}#{ICON_TYPE}")
    btn_ifc_import.large_icon = File.join(PLUGIN_PATH_IMAGE, "IfcImport#{ICON_LARGE}#{ICON_TYPE}")
    btn_ifc_import.tooltip = "Import IFC file"
    btn_ifc_import.status_bar_text = "Import IFC file"

    # IFC export button
    btn_ifc_export = UI::Command.new('Export model to IFC') {

      # get model current path
      model_path = Sketchup.active_model.path

      # get model file name
      if File.basename(model_path) == ""
        filename = "Untitled.ifc" # (?) translate?
      else
        filename = "#{File.basename(model_path, ".*")}.ifc"
      end

      # get model directory name
      dirname = File.dirname(model_path)

      # enter save path
      export_path = UI.savepanel('Export to IFC (.ifc/.ifcZIP)', dirname, filename)

      # only start export if path is valid
      unless export_path.nil?

        # make sure file_path ends in "ifc"
        unless [".ifc",".ifczip"].include? File.extname(export_path).downcase
          export_path << '.ifc'
        end

        export( export_path )
      end
    }
    btn_ifc_export.small_icon = File.join(PLUGIN_PATH_IMAGE, "IfcExport#{ICON_SMALL}#{ICON_TYPE}")
    btn_ifc_export.large_icon = File.join(PLUGIN_PATH_IMAGE, "IfcExport#{ICON_LARGE}#{ICON_TYPE}")
    btn_ifc_export.tooltip = 'Export model to IFC'
    btn_ifc_export.status_bar_text = 'Export model to IFC'

    # Open settings window
    btn_settings_window = UI::Command.new("IFC Manager settings") {
      Settings.toggle
    }
    btn_settings_window.small_icon = File.join(PLUGIN_PATH_IMAGE, "Settings#{ICON_SMALL}#{ICON_TYPE}")
    btn_settings_window.large_icon = File.join(PLUGIN_PATH_IMAGE, "Settings#{ICON_LARGE}#{ICON_TYPE}")
    btn_settings_window.tooltip = "Open IFC Manager settings"
    btn_settings_window.status_bar_text = "Open IFC Manager settings"

    @toolbar.add_item btn_settings_window
    @toolbar.add_item btn_ifc_import
    @toolbar.add_item btn_ifc_window
    @toolbar.add_item btn_ifc_export

    @toolbar.show

    # Add icons to command
    #
    # @param command [UI::Command]
    # @param name [UI::Command]
    def add_icons(command, name)

    end
  end # module IfcManager
end # module BimTools
