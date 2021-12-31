#  IfcUnitAssignment_su.rb
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

require_relative "IfcInteger.rb"

module BimTools
  module IfcUnitAssignment_su
    attr_reader :length_unit, :area_unit, :volume_unit
      
    include BimTools::IfcManager::Settings.ifc_module

    LENGTH_UNITS = [
      :Inches,
      :Feet,
      :Millimeter,
      :Centimeter,
      :Meter,
      :Yard
    ].freeze

    AREA_UNITS = [
      :SquareInches,
      :SquareFeet,
      :SquareMillimeter,
      :SquareCentimeter,
      :SquareMeter,
      :SquareYard
    ].freeze

    VOLUME_UNITS = [
      :CubicInches,
      :CubicFeet,
      :CubicMillimeter,
      :CubicCentimeter,
      :CubicMeter,
      :CubicYard,
      :Liter,
      :USGallon
    ].freeze

    IFC_UNITS = {
        :CubicMillimeter => ['.VOLUMEUNIT.','.MILLI.','.CUBIC_METRE.'],
        :CubicCentimeter => ['.VOLUMEUNIT.','.CENTI.','.CUBIC_METRE.'],
        :CubicMeter => ['.VOLUMEUNIT.','*','.CUBIC_METRE.'],
        :Liter => ['.VOLUMEUNIT.','.DECI.','.CUBIC_METRE.'],
        :Millimeter => ['.LENGTHUNIT.','.MILLI.','.METRE.'],
        :Centimeter => ['.LENGTHUNIT.','.CENTI.','.METRE.'],
        :Meter => ['.LENGTHUNIT.','*','.METRE.'],
        :SquareMillimeter => ['.AREAUNIT.','.MILLI.','.SQUARE_METRE.'],
        :SquareCentimeter => ['.AREAUNIT.','.CENTI.','.SQUARE_METRE.'],
        :SquareMeter => ['.AREAUNIT.','*','.SQUARE_METRE.']
    }

    CONVERSIONBASEDUNITS = {
        :SquareYard => [:SquareMeter,'.AREAUNIT.','SQUARE YARD',0.83612736,[2,0,0,0,0,0,0]],
        :CubicInches => [:CubicMeter,'.VOLUMEUNIT.','CUBIC INCH',1.6387064e-05,[3,0,0,0,0,0,0]],
        :CubicFeet => [:CubicMeter,'.VOLUMEUNIT.','CUBIC FOOT',0.028316846592,[3,0,0,0,0,0,0]],
        :CubicYard => [:CubicMeter,'.VOLUMEUNIT.','CUBIC YARD',0,764554857984,[3,0,0,0,0,0,0]],
        :USGallon => [:CubicMeter,'.VOLUMEUNIT.','US GALLON',0.00378541178,[3,0,0,0,0,0,0]],
        :Inches => [:Meter,'.LENGTHUNIT.','INCH',0.0254,[1,0,0,0,0,0,0]],
        :Feet => [:Meter,'.LENGTHUNIT.','FOOT',0.3048,[1,0,0,0,0,0,0]],
        :Yard => [:Meter,'.LENGTHUNIT.','YARD',0.9144,[1,0,0,0,0,0,0]],
        :SquareInches => [:SquareMeter,'.AREAUNIT.','SQUARE INCH',0.00064516,[2,0,0,0,0,0,0]],
        :SquareFeet => [:SquareMeter,'.AREAUNIT.','SQUARE FOOT',0.09290304,[2,0,0,0,0,0,0]]
    }

    def initialize(ifc_model)
      super
      @ifc_model = ifc_model
      @su_model = ifc_model.su_model
      set_units()
      @units = IfcManager::Ifc_Set.new()
      @units.add(ifc_unit(@length_unit))
      @units.add(ifc_unit(@area_unit))
      @units.add(ifc_unit(@volume_unit))
    end

    def set_units()
      unit_options = @su_model.options['UnitsOptions']
      @length_unit = LENGTH_UNITS[unit_options["LengthUnit"]]
      @area_unit = AREA_UNITS[unit_options["AreaUnit"]]
      @volume_unit = VOLUME_UNITS[unit_options["VolumeUnit"]]
    end

    def ifc_unit(unit_type)
      if IFC_UNITS.key? unit_type
        unit_values = IFC_UNITS[unit_type]
        unit = IfcSIUnit.new( @ifc_model )
        unit.dimensions = '*'
        unit.unittype = unit_values[0]
        unit.prefix = unit_values[1]
        unit.name = unit_values[2]
        return unit
      else
        unit_values = CONVERSIONBASEDUNITS[unit_type]
        conversionbasedunit = IfcConversionBasedUnit.new( @ifc_model )
        dimensions = IfcDimensionalExponents.new( @ifc_model )
        dimensions.lengthexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][0])
        dimensions.massexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][1])
        dimensions.timeexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][2])
        dimensions.electriccurrentexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][3])
        dimensions.thermodynamictemperatureexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][4])
        dimensions.amountofsubstanceexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][5])
        dimensions.luminousintensityexponent = BimTools::IfcManager::IfcInteger.new(unit_values[4][6])
        conversionbasedunit.dimensions = dimensions
        conversionbasedunit.unittype = unit_values[1]
        conversionbasedunit.name = BimTools::IfcManager::IfcLabel.new(unit_values[2])
        measurewithunit = IfcMeasureWithUnit.new( @ifc_model )
        conversionbasedunit.conversionfactor = measurewithunit
        unit = IfcSIUnit.new( @ifc_model )
        case unit_values[1]
        when '.LENGTHUNIT.'
          valuecomponent = BimTools::IfcManager::IfcLengthMeasure.new( @ifc_model, unit_values[3])
        when '.AREAUNIT.'
          valuecomponent = BimTools::IfcManager::IfcAreaMeasure.new( unit_values[3])
        when '.VOLUMEUNIT.'
          valuecomponent = BimTools::IfcManager::IfcVolumeMeasure.new( unit_values[3])
        end
        valuecomponent.long = true
        measurewithunit.valuecomponent = valuecomponent
        measurewithunit.unitcomponent = unit
        measured_unit_values = IFC_UNITS[unit_values[0]]
        unit.dimensions = '*'
        unit.unittype = measured_unit_values[0]
        unit.prefix = measured_unit_values[1]
        unit.name = measured_unit_values[2]
        return conversionbasedunit
      end
    end
  end
end
