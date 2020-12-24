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

module BimTools::IfcManager
  require File.join(PLUGIN_PATH_UI, 'form_element.rb')
    module PropertiesWindow      
      class HtmlSelect < FormElement
        attr_reader:options

        def initialize(dialog, name)
          super(dialog)
          @id = name.gsub(/[^0-9A-Za-z]/, '').downcase
          @name = name
          @button = false
        end

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
        end

        def html(selection)
          if @hidden
            hide_css = " style=\"display:none;\""
          else
            hide_css = ""
          end
          if @button == true
            html =  "<div class=\"form-group row #{@id}_row\"#{hide_css}>"
            html << "<label for=\"#{@id}\" class=\"col-3 col-form-label\">#{@name}:</label>"
            html << "<div class=\"input-group col-9 #{@id}_row\">"
            html << "<select class=\"form-control\" id=\"#{@id}\"></select>"
            html << "<div class=\"input-group-append\">"
            html << "<button class=\"btn\" type=\"button\" id=\"add_#{@id}\">+</button>"
            html << "</div></div></div>"
            return html
          else
            html =  "<div class=\"form-group row #{@id}_row\"#{hide_css}>"
            html << "<label for=\"#{@id}\" class=\"col-3 col-form-label\">#{@name}:</label>"
            html << "<div class=\"col-9 #{@id}_row\">"
            html << "<select class=\"form-control\" id=\"#{@id}\" data-width=\"100%\"></select>"
            html << "</div></div>"
            return html
          end
        end

        def add_button()
          @button = true
        end

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

        def update(selection)
          set_value()
          case @value
          when nil || "-"
            index = "'-'"
          when "..."
            index = "'...'"
          else
            index = @options.index(@value)
          end
          self.dialog.execute_script("$('##{@id}').val(#{index}).trigger('change');")

        end

        def set_value()
          puts 'No value update method defined'
        end

        # common method to set the value for all html selects
        # that are based on the current sketchup selection
        def set_value_from_list(list)
          case list.length
          when 0
            @value = "-"
          when 1
            if list[0].nil?
              @value = "-"
            else
              @value = list[0]
            end
          else
            self.dialog.execute_script("if(!$('##{@id}').find(\"option[value='...']\").length) {\nvar newOption = new Option('...', '...', false, false);\n$('##{@id}').append(newOption).trigger('change');\n}")
            @value = "..."
          end
        end

        def set_callback()
        end
      end
    end
  end