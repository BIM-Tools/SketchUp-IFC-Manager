#  IfcReal.rb
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

require_relative 'Ifc_Type'

module BimTools::IfcManager
  class IfcReal < Ifc_Type
    def initialize(ifc_model, value, long = false)
      super
      begin
        @value = value.to_f
      rescue StandardError, TypeError => e
        print value << 'cannot be converted to a Float: ' << e
      end
    end

    # Convert float to STEP formatted STEP string taking into account possible scientific notation
    def to_step_string(value)
      val = value.to_s.upcase.gsub(/(\.)0+$/, '.')
      val = add_long(val) if @long
      val
    end

    def step
      to_step_string(@value)
    end
  end
end
