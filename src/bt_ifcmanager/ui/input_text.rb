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

module BimTools
  module IfcManager
    module PropertiesWindow      
      class HtmlInputText
        attr_reader :id
        attr_accessor :onchange, :value
        def initialize(dialog, name)
          @dialog = dialog
          @name = name
          @id = name.gsub(/[^0-9A-Za-z]/, '')
          @js = ""
          @onchange = ""
        end
        def js()
          "$('##{@id}').on('change',function(e){sketchup.#{@id}($('##{@id}')[0].value,$('##{@id}')[0].id);});"
        end
        def html(selection)
          set_value()
          html =  "<div class=\"form-group row\">"
          html << "<label for=\"#{@id}\" class=\"col-3 col-form-label\">#{@name}:</label>"
          html << "<div class=\"col-9\">"
          html << "<input type=\"text\" class=\"form-control\" id=\"#{@id}\" value=\"#{@value}\" autocomplete=\"off\">"
          html << "</div></div>"
        end
      end # class HtmlInputText
    end # module PropertiesWindow
  end # module IfcManager
end # module BimTools