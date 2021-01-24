#  input_text.rb
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
# input text element

module BimTools::IfcManager
  require File.join(PLUGIN_PATH_UI, 'form_element.rb')
  module PropertiesWindow
    class Title < FormElement
      def initialize(dialog, text="")
        super(dialog)
        @text = text
      end
      def get_text(selection)
        components = []
        groups = []
        other = []
        selection_count = selection.length
        i = 0
        while i < selection_count
          ent = selection[i]
          if(ent.is_a?(Sketchup::ComponentInstance))
            components << ent
          elsif(ent.is_a?(Sketchup::Group))
            groups << ent
          else
            other << ent
          end
          i += 1
        end
        if other.length > 0
          @text = "#{selection.length.to_s} entities"
        elsif components.length > 0 && groups.length > 0
          @text = "#{selection.length.to_s} Components and Groups"
        elsif components.length > 1
          @text = "#{selection.length.to_s}  Components"
        elsif groups.length > 1
          @text = "#{selection.length.to_s} Groups"
        elsif components.length > 0
          @text = "Component (#{components[0].definition.count_used_instances.to_s} in model)"
        elsif groups.length > 0
          @text = "Group (#{groups[0].definition.count_used_instances.to_s}  in model)"
        else
          @text = "No selection"
        end
        return @text.to_s
      end # get_text

      def html(selection)
        return "<h1 id='title'>#{get_text(selection)}</h1>"
      end
      def update(selection)
        self.dialog.execute_script("$('#title').html('#{get_text(selection)}');")
      end
    end # class Title
  end # module PropertiesWindow
end