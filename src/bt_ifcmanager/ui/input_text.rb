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
    class HtmlInputText < FormElement

      def initialize(dialog, name)
        super(dialog)
        @id = name.gsub(/[^0-9A-Za-z]/, '')
        @name = name
      end

      def js()
        "$('##{@id}').on('change',function(e){sketchup.#{@id}($('##{@id}')[0].value,$('##{@id}')[0].id);});"
      end

      def html(selection)
        if @hidden
          hide_css = " style=\"display:none;\""
        else
          hide_css = ""
        end
        set_value()
        <<-HTML
          <div class="form-group row #{@id}_row"#{hide_css}>
          <label for="#{@id}" class="col-3 col-form-label">#{@name}:</label>
          <div class="col-9">
          <input type="text" class="form-control" id="#{@id}" value="#{@value}" autocomplete="off">
          </div></div>
        HTML
      end

      def update(selection)
        set_value()
        self.dialog.execute_script("$('##{@id}').val('#{@value}');")
      end

      def set_value()
      end
    end
  end
end