#  IfcSpaceThermalLoadProperties.rb
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

require_relative(File.join('..', 'step.rb'))
require_relative(File.join('..', 'IfcJson.rb'))
require_relative('IfcPropertySetDefinition.rb')

module BimTools
 module IFC2X3
  class IfcSpaceThermalLoadProperties < IfcPropertySetDefinition
    attr_accessor :ifc_id, :applicablevalueratio, :thermalloadsource, :propertysource, :sourcedescription, :maximumvalue, :minimumvalue, :thermalloadtimeseriesvalues, :userdefinedthermalloadsource, :userdefinedpropertysource, :thermalloadtype
    include Step 
    include IfcJson 
    def initialize( ifc_model, sketchup=nil, *args ) 
      @ifc_id = ifc_model.add( self ) if @ifc_id.nil?
      super
    end # def initialize 
    def properties()
      return [:GlobalId, :OwnerHistory, :Name, :Description, :ApplicableValueRatio, :ThermalLoadSource, :PropertySource, :SourceDescription, :MaximumValue, :MinimumValue, :ThermalLoadTimeSeriesValues, :UserDefinedThermalLoadSource, :UserDefinedPropertySource, :ThermalLoadType]
    end # def properties
  end # class IfcSpaceThermalLoadProperties
 end # module IFC2X3
end # module BimTools
