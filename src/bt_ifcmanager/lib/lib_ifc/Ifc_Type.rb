#  Ifc_Type.rb
#
#  Copyright 2018 Jan Brouwer <jan@brewsky.nl>
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

module BimTools::IfcManager
  class Ifc_Type
    attr_accessor :long

    # https://technical.buildingsmart.org/wp-content/uploads/2018/05/IFC2x-Model-Implementation-Guide-V2-0b.pdf
    # page 19 and 20
    def replace_char( in_string )
      out_string = ""
      a_char_numbers = in_string.unpack('U*')
      i = 0
      while i < a_char_numbers.length do
        case a_char_numbers[i]
        when (0..31), 39, 92 # \X\code , 39 is the ansii number for the quote character ' , and 92 is \
          out_string << "\\X\\#{("%02x" % a_char_numbers[i]).upcase}"
        when 32..127
          out_string << a_char_numbers[i]
        when 128..255 # \S\code
          out_string << "\\S\\" << a_char_numbers[i] - 128
        when 256..65535 # \X2\code\X0\
          out_string << "\\X2\\#{("%04x" % a_char_numbers[i]).upcase}\\X0\\"
        else # \X4\code\X0\
          out_string << "\\X4\\#{("%08x" % a_char_numbers[i]).upcase}\\X0\\"
        end
        i += 1
      end
      return out_string
    end
    
    # adding long = true returns a full object string
    def add_long( string )
      classname = self.class.name.split('::').last.upcase
      return "#{classname}(#{string})"
    end
  end
end
