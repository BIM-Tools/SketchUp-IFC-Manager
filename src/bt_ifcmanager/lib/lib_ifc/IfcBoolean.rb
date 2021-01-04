#  IfcBoolean.rb
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

require_relative 'Ifc_Type.rb'

module BimTools::IfcManager
  class IfcBoolean < Ifc_Type
    def initialize( value )
      puts value.class
      self.value=(value)
    end
    
    def value=(value)
      case value
      when NilClass, ""
        @value = nil
      when TrueClass, FalseClass
        @value = value
      else

        # see if casting it to a string makes it a boolean type
        case value.to_s.downcase
        when "true"
          @value = true
        when "false"
          @value = false
        else        
          @value = nil
          BimTools::IfcManager::add_export_message("IfcBoolean must be true or false, not #{value.to_s}")
        end
      end
    end

    def step()
      case @value
      when TrueClass
        value = ".T."
      when FalseClass
        value = ".F."
      else
        return "$"
      end
      if @long
        value = add_long( value )
      end
      return value
    end
    
    def true?(obj)
      obj.to_s == "true"
    end
  end
end
