#  bt_ifcmanager.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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
require 'sketchup.rb'
require 'extensions.rb'

module BimTools
  PLUGIN_ROOT_PATH = File.dirname(__FILE__) unless defined? PLUGIN_ROOT_PATH

  module IfcManager
    VERSION = '2.1.2'.freeze
    
    # load plugin only if SketchUp version is PRO
    if Sketchup.is_pro? && Sketchup.version_number>1600000000
      PLUGIN_PATH       = File.join(PLUGIN_ROOT_PATH, 'bt_ifcmanager')
      PLUGIN_IMAGE_PATH = File.join(PLUGIN_PATH, 'images')

      ifcmanager_extension = SketchupExtension.new("IFC Manager", File.join(PLUGIN_PATH, 'loader.rb'))
      ifcmanager_extension.version = VERSION
      ifcmanager_extension.description = 'IFC data manager and exporter for SketchUp.'
      ifcmanager_extension.creator = 'BIM-Tools'
      ifcmanager_extension.copyright = '2018'
      Sketchup.register_extension(ifcmanager_extension, true)
      IFCMANAGER_EXTENSION = ifcmanager_extension
    else
      UI.messagebox "You need at least SketchUp Pro 2016 to use this extension."
    end
  end # module IfcManager
end # module BimTools
