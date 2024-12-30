# frozen_string_literal: true

#  IfcClassificationReference_su.rb
#
#  Copyright 2024 Jan Brouwer <jan@brewsky.nl>
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
  module IfcClassificationReference_su
    attr_accessor :classificationrefforobjects

    def initialize(ifc_model)
      super
      @ifc_module = ifc_model.ifc_module
    end

    def self.required_attributes(_ifc_version)
      [:ReferencedSource]
    end

    def ifcx
      return unless @classificationrefforobjects

      relatedobjects = @classificationrefforobjects.relatedobjects
      uri = @location.ifcx if @location
      code = ifc5_code
      name = @name.ifcx
      classification_name = @referencedsource.name.ifcx
      classification_code = classification_name.gsub(/[^0-9A-Za-z]/, '')

      relatedobjects.map do |relatedobject|
        {
          'def' => 'over',
          'comment' => "Classification reference: '#{name}' for classification: '#{classification_name}'",
          'name' => "#{relatedobject.globalid.ifcx}",
          'attributes' => { "#{classification_code}:class" => {
            'code' => code,
            'uri' => uri
          } }
        }
      end
    end

    def ifc5_code
      if instance_variable_defined?(:@identification)
        @identification.ifcx if @identification
      elsif instance_variable_defined?(:@itemreference)
        @itemreference.ifcx if @itemreference
      end
    end
  end
end
