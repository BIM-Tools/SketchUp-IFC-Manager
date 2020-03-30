#  observers.rb
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
  class Observers
    def initialize()
      Sketchup.add_observer(IMAppObserver.new)
      @sel_observer = IMSelectionObserver.new
      @ent_observer = IMEntitiesObserver.new
      @app_observer = IMAppObserver.new
    end

    # Attach observers on menu open
    def start()
      Sketchup.active_model.selection.add_observer(@sel_observer)
      Sketchup.active_model.entities.add_observer(@ent_observer) # (?) always the active entities object?
      Sketchup.active_model.selection.add_observer(@app_observer)
    end # def start

    # Remove observers on menu close
    def stop()
      Sketchup.active_model.selection.remove_observer(@sel_observer)
      Sketchup.active_model.entities.remove_observer(@ent_observer) # (?) always the active entities object?
      Sketchup.active_model.selection.remove_observer(@app_observer)
    end # def stop
  end # class Observers

  # observer that updates the window on selection change
  class IMSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(selection)
      PropertiesWindow.set_html()
    end
    def onSelectionCleared(selection)
      PropertiesWindow.set_html()
    end
    def onSelectionAdded(selection,entity)
      PropertiesWindow.set_html()
    end
  end

  # observer that updates the window when selected entity changes
  class IMEntitiesObserver < Sketchup::EntitiesObserver
    def onElementModified(entities,entity)
      if Sketchup.active_model.selection.include?(entity)
        PropertiesWindow.set_html()
      end
    end
    def onElementAdded(entities,entity)
      if entity.deleted? || Sketchup.active_model.selection.include?(entity)
        PropertiesWindow.set_html()
      end
    end
  end
  
  class IMAppObserver < Sketchup::AppObserver
    def onNewModel(model)
      switch_model()
    end
    def onOpenModel(model)
      switch_model()
    end
    
    # actions when switching/loading models
    def switch_model()
      
      # when new model is loaded, close window (?) instantaneous re-open does not work?
      PropertiesWindow.close
      PropertiesWindow.create
      
      # also load classifications and default materials into new model
      Settings.load_classifications
      Settings.load_materials()
    end
  end
 end # module IfcManager
end # module BimTools
