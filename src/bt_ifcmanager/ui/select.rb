#  select.rb
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
# select2

require 'json'

module BimTools
    module IfcManager
      module PropertiesWindow      
        class HtmlSelect
          attr_reader :id, :options
          attr_accessor :js, :onchange, :value

          def initialize(dialog, name)
            @dialog = dialog
            @name = name
            @id = name.gsub(/[^0-9A-Za-z]/, '')
            @js = ""
            @onchange = ""
            @button = false
            add_save_command(dialog)
          end # def initialize

          def options=(options)
            if options.is_a? Array
              @options = options
              @js_options = [{:id => "-", :text => "-"}]
              i = 0
              while i < options.length() do
                @js_options << {:id => i, :text => options[i]}
                i += 1
              end
            end
          end # def options

          def add_save_command(dialog)
          end
          def js()
            if @value
              if @value == "..."
                index = "'...'"
              else
                index = @options.index(@value)
              end
              return @js << "$('##{@id}').val(#{index});\n$('##{@id}').trigger('change');\n"
            else
              return @js << "$('##{@id}').val('-');\n$('##{@id}').trigger('change');\n"
            end
          end # def add_save_command

          def html(selection)
            if @button == true
              html =  "<div class=\"form-group row\">"
              html << "<label for=\"#{@id}\" class=\"col-3 col-form-label\">#{@name}:</label>"
              html << "<div class=\"input-group col-9\">"
              html << "<select class=\"form-control\" id=\"#{@id}\"></select>"
              html << "<div class=\"input-group-append\">"
              html << "<button class=\"btn\" type=\"button\" id=\"add_#{@id}\">+</button>"
              html << "</div></div></div>"
              return html
            else
              html =  "<div class=\"form-group row\">"
              html << "<label for=\"#{@id}\" class=\"col-3 col-form-label\">#{@name}:</label>"
              html << "<div class=\"col-9\">"
              html << "<select class=\"form-control\" id=\"#{@id}\" data-width=\"100%\"></select>"
              html << "</div></div>"
              return html
            end
          end # def html

          def add_button()
            @button = true
          end # def add_button

          def set_options(extra=false)
            json_options = @js_options
            if extra
              json = (@js_options + [{:id => extra,:text => extra}]).to_json
            else
              json = @js_options.to_json
            end
            @js = "$('##{@id}').select2({data: #{json}})\n"
            @js << "$('#add_#{@id}').click(function() {sketchup.add_#{@id}()});"
            @onchange = "$('##{@id}').on('select2:select', function (e) { sketchup.#{@id}(e.params.data.text)});"
          end
        end # class HtmlSelect
      end # module PropertiesWindow
    end # module IfcManager
  end # module BimTools