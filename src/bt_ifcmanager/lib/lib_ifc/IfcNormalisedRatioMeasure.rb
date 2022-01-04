#  IfcNormalisedRatioMeasure.rb
#
#  Copyright 2021 Jan Brouwer <jan@brewsky.nl>
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

require_relative 'IfcRatioMeasure'

module BimTools::IfcManager
  class IfcNormalisedRatioMeasure < IfcRatioMeasure
    def initialize(value)
      super
      if @value < 0 || @value > 1
        raise 'Error creating IfcNormalisedRatioMeasure: Normalized ratio shall be a non-negative value less than or equal to 1.0'
      end
    end
  end
end
