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

module BimTools
 module IfcManager
  
  require File.join(PLUGIN_PATH, 'observers.rb')

  SKUI_PATH = File.join( PLUGIN_PATH_LIB, 'SKUI' )
  load File.join( SKUI_PATH, 'embed_skui.rb' )
  ::SKUI.embed_in( self )

  module PropertiesWindow
    attr_reader :window, :ready

    extend self
  
    # create observers
    @observers = IfcManager::Observers.new()

    @visible = false
    @ready = false
    @sections = Array.new

    options = {
      :title           => 'Edit IFC properties',
      :preferences_key => 'BimTools-IfcManager-PropertiesWindow',
      :width           => 400,
      :height          => 400,
      :resizable       => true,
      :theme           => File.join( PLUGIN_PATH_CSS, 'core.css' ).freeze
    }
    @window = SKUI::Window.new( options )

    # check if window is ready
    @window.on( :ready ) {
      @ready = true
      update
    }
    
    @window.on( :close ) {
      @observers.stop
    }

    require File.join( PLUGIN_PATH, 'menu_section.rb' )
    require File.join( PLUGIN_PATH, 'entity_info.rb' )

    def update
      #if @visible
        # update menu contents
        EntityInfo.update( Sketchup.active_model.selection )
      #end
    end # update

    def close
      @observers.stop
      if @window
        @window.close
      end
      #@window.window.close
    end # def close

    def show
      @observers.start
      @window.show
    end # def show

    def toggle # (!) stop/start observer
      if @window.visible?
        self.close
      else
        self.show
      end
    end # def toggle
   end # module PropertiesWindow
 end # module IfcManager
end # module BimTools
