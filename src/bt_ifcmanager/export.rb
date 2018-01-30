#  export.rb
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

require_relative File.join('lib', 'lib_ifc', 'IfcModel.rb')

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH, 'update_ifc_fields.rb')

    def export( file_path )
      require File.join(PLUGIN_PATH, 'lib', 'progressbar.rb')
      
      pb = ProgressBar.new(4,"Exporting to IFC...")
      
      # start timer
      timer = Time.now
      
      # check if it's possible to write IFC files
      unless Sketchup.is_pro?
        raise "You need SketchUp PRO to create IFC-files"
      end
      
      su_model = Sketchup.active_model
      
      options = {
        #:ifc_entities     => false,  # include IFC entity types given in array, like ["IfcWindow", "IfcDoor"], false means all
        #:hidden           => false,  # include hidden sketchup objects
        #:all_attributes   => false,  # add all SketchUp attributes as IfcPropertySets
        #:classifications  => true,   # add all SketchUp classifications
        #:layers           => true,   # create IfcPresentationLayerAssignments
        #:materials        => true,   # create IfcMaterials
        #:styles           => true,   # create IfcStyledItems
        #:fast_guid        => false   # create simplified guids
      }
      
      # update all IFC name fields with the component definition name
      # (?) is this necessary, or should this already be 100% correct at the time of export?
      su_model.start_operation('Update IFC data', true)
      update_ifc_fields( su_model )
      su_model.commit_operation
      
      pb.update(1)

      # make sure file_path ends in "ifc"
      unless file_path.split('.').last == "ifc"
        file_path << '.ifc' # (!) creates duplicate extentions when extention exists
      end
      
      # create new IfcModel
      ifc_model = IfcModel.new( su_model, options )
      
      pb.update(2)
      
      # get total time
      puts "finished creating IFC entities: " + (Time.now - timer).to_s
      
      # export model to IFC step file
      ifc_model.export( file_path )
      
      pb.update(3)
      
      # get total time
      time = Time.now - timer
      puts "finished export: " + time.to_s
      
      pb.update(4)
      
      show_summary( ifc_model.export_summary, file_path, time )
    end # export
    def show_summary( hash, file_path, time )
      css = File.join(PLUGIN_PATH_CSS, 'sketchup.css')
      html = "<html><head><link rel='stylesheet' type='text/css' href='" + css + "'></head><body><textarea readonly>IFC Entities exported:\n\n"
      hash.each_pair do | key, value |
        html << value.to_s + " " + key.to_s + "\n"
      end
      html << "\n To file '" + file_path + "'\n"
      html << "\n Taking a total number of " + time.to_s + " seconds\n"
      html << "</textarea></body></html>"
      dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Export results",
        :scrollable => false,
        :resizable => true,
        :width => 320,
        :height => 380,
        :left => 100,
        :top => 100,
        :style => UI::HtmlDialog::STYLE_UTILITY
      })
      dialog.set_html( html )
      dialog.show
    end
  end # module IfcManager
end # module BimTools
