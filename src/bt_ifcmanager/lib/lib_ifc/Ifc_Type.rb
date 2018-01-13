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

module BimTools
 module IfcManager
  class Ifc_Type
    attr_accessor :long
    def replace_char( string )
      
      # check for characters in the string that cannot be converted to STEP and replace them
      ec = Encoding::Converter.new("UTF-8", "ISO-8859-1")
      begin
        str_replace = ec.convert( string )
      rescue Encoding::UndefinedConversionError
        #puts $!.error_char.dump
        #p $!.error_char.encoding
        #puts $!.error_char.unpack('H*').to_s
        #str_replace = string.gsub($!.error_char, "\X\\" + $!.error_char.unpack('H*').to_s)
        #str_replace = str_replace.inspect # escape all special characters, double quotes?
        
        # replace some common charecters with the correct STEP code, otherwise with "?"
        # could be improved by using the correct byte hex code to generate the replacement
        # http://www.buildingsmart-tech.org/implementation/get-started/string-encoding
        # http://www.fileformat.info/info/charset/ISO-8859-1/list.htm
        case $!.error_char
        when "\\"
          replace_char = '\X\\\5c'
        when "`"
          replace_char = '\X\\\60'
        when "'"
          replace_char = '\X\\\91'
        when "’"
          replace_char = '\X\\\92'
        else
          replace_char = '?'
        end
        str_replace = string.gsub($!.error_char, replace_char)
      end
      return str_replace
    end
    
    # adding long = true returns a full object string
    def add_long( string )
      puts self
      puts "LONG"
      puts classname = self.class.name.split('::').last.upcase
      return classname + "(" + string + ")"
    end
  end # class Ifc_Type
 end # module IfcManager
end # module BimTools
