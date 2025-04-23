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
    require File.join(PLUGIN_PATH_UI, 'form_element')
    module PropertiesWindow
      class HtmlSelect < FormElement
        attr_reader :options

        def initialize(dialog, name)
          super(dialog)
          @id = name.gsub(/[^0-9A-Za-z]/, '').downcase
          @name = name
          @button = false
          @index_max = 0
        end

        def set_js_options(options, options_template = [])
          return unless options.is_a? Array

          @options = options
          @js_options = options_template
          i = 0
          while i < options.length
            @js_options << { id: i, text: options[i] }
            i += 1
          end
          @index_max = i
        end

        def js
          return @js << "$('##{@id}').val('-');\n$('##{@id}').trigger('change');\n" unless @value

          index = if @value == '...'
                    "'...'"
                  else
                    @options.index(@value)
                  end
          @js << "$('##{@id}').val(#{index});\n$('##{@id}').trigger('change');\n"
        end

        def html(_selection)
          hide_css = if @hidden
                       ' style="display:none;"'
                     else
                       ''
                     end
          return <<-HTML if @button == true

              <div class="form-group row #{@id}_row"#{hide_css}>
              <label for="#{@id}" class="col-3 col-form-label">#{@name}:</label>
              <div class="input-group col-9 #{@id}_row">
              <select class="form-control" id="#{@id}"></select>
              <div class="input-group-append">
              <button class="btn" type="button" id="add_#{@id}">+</button>
              </div></div></div>
          HTML

          <<-HTML
              <div class="form-group row #{@id}_row"#{hide_css}>
              <label for="#{@id}" class="col-3 col-form-label">#{@name}:</label>
              <div class="col-9 #{@id}_row">
              <select class="form-control" id="#{@id}" data-width="100%"></select>
              </div></div>
          HTML
        end

        def add_button
          @button = true
        end

        def set_options(extra = false)
          json_options = @js_options
          json = if extra
                   (@js_options + [{ id: extra, text: extra }]).to_json.force_encoding('UTF-8')
                 else
                   @js_options.to_json.force_encoding('UTF-8')
                 end
          @js = "$('##{@id}').select2({data: #{json}})\n"
          @js << "$('#add_#{@id}').click(function() {sketchup.add_#{@id}()});"
          @onchange = "$('##{@id}').on('select2:select', function (e) { sketchup.#{@id}(e.params.data.text)});"
        end

        def update(_selection)
          set_value
          index = case @value
                  when nil || '-'
                    "'-'"
                  when '...'
                    "'...'"
                  else
                    @options.index(@value)
                  end
          dialog.execute_script("$('##{@id}').val(#{index});\n$('##{@id}').trigger('change');")
        end

        def set_value
          puts 'No value update method defined'
        end

        # common method to set the value for all html selects
        # that are based on the current sketchup selection
        def set_value_from_list(list)
          case list.length
          when 0
            @value = '-'
          when 1
            @value = if list[0].nil?
                       '-'
                     else
                       list[0]
                     end
          else
            dialog.execute_script("if(!$('##{@id}').find(\"option[value='...']\").length) {\nvar newOption = new Option('...', '...', false, false);\n$('##{@id}').append(newOption).trigger('change');\n}")
            @value = '...'
          end
        end

        def set_callback; end

        def hide
          # Also hide dropdown when form elements are hidden
          dialog.execute_script("$('##{@id}').select2('close');")
          super()
        end
      end
    end
  end
end
