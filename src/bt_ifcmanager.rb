# frozen_string_literal: true

#  bt_ifcmanager.rb
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

# Create an entry in the Extension list that loads a script called
# loader.rb.

require 'sketchup'
require 'extensions'

module BimTools
  PLUGIN_ROOT_PATH = File.dirname(__FILE__) unless defined? PLUGIN_ROOT_PATH

  module IfcManager
    # Version and release information.
    VERSION = '5.2.0'

    # load plugin only if SketchUp version is PRO
    # raised minimum version to 2017 due to switch to htmldialog
    if Sketchup.version_number > 1_700_000_000
      PLUGIN_PATH       = File.join(PLUGIN_ROOT_PATH, 'bt_ifcmanager')
      PLUGIN_IMAGE_PATH = File.join(PLUGIN_PATH, 'images')

      IFCMANAGER_EXTENSION = SketchupExtension.new('IFC Manager', File.join(PLUGIN_PATH, 'loader'))
      IFCMANAGER_EXTENSION.version = VERSION
      IFCMANAGER_EXTENSION.description = 'IFC data manager and exporter for SketchUp.'
      IFCMANAGER_EXTENSION.creator = 'BIM-Tools'
      IFCMANAGER_EXTENSION.copyright = '2017-2023'
      Sketchup.register_extension(IFCMANAGER_EXTENSION, true)
    else
      UI.messagebox 'You need at least SketchUp 2017 to use this extension.'
    end
  end
end
