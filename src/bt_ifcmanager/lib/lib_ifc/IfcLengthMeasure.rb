#  IfcLengthMeasure.rb
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

require_relative 'IfcReal.rb'

module BimTools::IfcManager

  # A length measure is the value of a distance.
  #   Usually measured in millimeters (mm).
  class IfcLengthMeasure < IfcReal
    def initialize(ifc_model, value)
      @ifc_model = ifc_model
      super(value)
    end

    def mm()
      @value = @value.mm
    end

    def cm()
      @value = @value.cm
    end

    def m()
      @value = @value.m
    end

    def km()
      @value = @value.km
    end

    def inch()
      @value = @value.inch
    end

    def feet()
      @value = @value.feet
    end

    def yard()
      @value = @value.yard
    end

    def mile()
      @value = @value.mile
    end

    def convert()      
      case @ifc_model.units.length_unit
      when :Millimeter
        return @value.to_mm
      when :Centimeter
        return @value.to_cm
      when :Meter
        return @value.to_m
      # when :Kilometer
      #   return @value.to_km
      when :Feet
        return @value.to_feet
      # when :Mile
      #   return @value.to_mile
      when :Yard
        return @value.to_yard
      else # default is :Inches
        return @value
      end
    end
    
    def step()
      return to_step_string(convert())
    end
  end
end
