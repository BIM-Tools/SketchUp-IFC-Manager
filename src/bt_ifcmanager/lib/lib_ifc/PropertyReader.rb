#  PropertyReader.rb
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

module BimTools
  class PropertyReader
    attr_reader :name, :value, :value_type, :attribute_type
    def initialize( attr_dict )
      @name = attr_dict.name
      @value = false
      @value_type = false
    
      # get data for objects with additional nesting levels
      # like: path = ["IFC 2x3", "IfcWindow", "Name", "IfcLabel"]
      if !attr_dict["value"] && attr_dict.attribute_dictionaries
        val_dict = false
        attr_dict.attribute_dictionaries.each do |dict|
          if dict.name != "instanceAttributes"
            val_dict = dict
            break
          end
        end
        
        @value = val_dict["value"]
        @value_type = val_dict.name
        @attribute_type = val_dict["attribute_type"]

        # Sometimes the value is even nested a level deeper
        # like: path = ["IFC 2x3", "IfcWindow", "OverallWidth", "IfcPositiveLengthMeasure", "IfcLengthMeasure"]
        if !@value && val_dict.attribute_dictionaries
          subtype_dict = false
          val_dict.attribute_dictionaries.each do |dict|
            if dict.name != "instanceAttributes"
              subtype_dict = dict
              break
            end
          end
          @value = subtype_dict["value"]
        end
      else
        # val_dict = attr_dict
        @value = attr_dict["value"]
        @attribute_type = attr_dict["attribute_type"]
      end
    end
  end
end
