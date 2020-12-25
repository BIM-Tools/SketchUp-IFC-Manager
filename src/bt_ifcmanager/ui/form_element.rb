#  form_element.rb
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
# form element

module BimTools::IfcManager
  module PropertiesWindow
    class FormElement
      attr_reader :id, :dialog
      attr_accessor :js, :onchange, :value, :hidden
      def initialize(dialog)
        @dialog = dialog
        @js = ""
        @onchange = ""
        @value = ""
        @hidden = false
      end
      def html()
        ""
      end
      def js()
        ""
      end
      def update(selection)
      end
      def set_callback()
      end

      # When no components or groups are selected all form elements are hidden
      def hide()
        @hidden = true
        @dialog.execute_script("$('.#{@id}_row').hide();")
      end

      # When components or groups are selected all form elements are shown
      def show()
        @hidden = false
        @dialog.execute_script("$('.#{@id}_row').show();")
      end
    end
  end
end