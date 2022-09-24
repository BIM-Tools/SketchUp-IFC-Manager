#  step_types.rb
#
#  Copyright 2022 Jan Brouwer <jan@brewsky.nl>
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
    module Types

      class List < Array
        include Step

        def add(entity)
          self << entity
        end

        def step
          "(#{map { |item| property_to_step(item) }.join(',')})"
        end
      end

      class Set < Set
        include Step

        def add(entity)
          self << entity
        end

        def step
          "(#{map { |item| property_to_step(item) }.join(',')})"
        end
      end

      class Enumeration
        attr_reader :value

        def initialize( value )
          @value = value.to_s
        end

        def step()
          val = ".#{@value.upcase}."
          if @long
            val = add_long( val )
          end
          return val
        end
      end
    end
  end
end