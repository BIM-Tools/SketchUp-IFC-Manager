# frozen_string_literal: true

#  ifc_types.rb
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

require_relative 'step_types'

module BimTools
  module IfcManager
    module Types

      # https://technical.buildingsmart.org/wp-content/uploads/2018/05/IFC2x-Model-Implementation-Guide-V2-0b.pdf
      # page 19 and 20
      def self.replace_char(in_string)
        out_string = +''
        a_char_numbers = in_string.unpack('U*')
        i = 0
        while i < a_char_numbers.length
          case a_char_numbers[i]
          when (0..31), 39, 92 # \X\code , 39 is the ansii number for the quote character ' , and 92 is \
            out_string << "\\X\\#{('%02x' % a_char_numbers[i]).upcase}"
          when 32..127
            out_string << a_char_numbers[i]
          when 128..255 # \S\code
            out_string << '\\S\\' << a_char_numbers[i] - 128
          when 256..65_535 # \X2\code\X0\
            out_string << "\\X2\\#{('%04x' % a_char_numbers[i]).upcase}\\X0\\"
          else # \X4\code\X0\
            out_string << "\\X4\\#{('%08x' % a_char_numbers[i]).upcase}\\X0\\"
          end
          i += 1
        end
        out_string
      end

      # Basic IFC Type class inherited by most other IFC Types
      class BaseType
        attr_accessor :value, :long

        @@not_boolean = "Parameter 'long' must be 'true' or 'false'"
        @@boolean = [true, false]

        def initialize(ifc_model, value, long = false)
          @ifc_model = ifc_model
          @value = value
          raise(ArgumentError, @@not_boolean) unless @@boolean.include? long

          @long = long
        end

        # adding long = true returns a full object string
        def add_long(string)
          classname = self.class.name.split('::').last.upcase
          "#{classname}(#{string})"
        end

        # Type objects don't have references, instead return step serialization
        def ref
          step
        end
      end

      # TYPE IfcReal = REAL;
      # END_TYPE;
      class IfcReal < BaseType
        def initialize(ifc_model, value, long = false)
          super
          @value = value.to_f
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

      # TYPE IfcAbsorbedDoseMeasure = REAL;
      # END_TYPE;

      # TYPE IfcAccelerationMeasure = REAL;
      # END_TYPE;

      # TYPE IfcAmountOfSubstanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcAngularVelocityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcArcIndex = LIST [3:3] OF IfcPositiveInteger;
      # END_TYPE;

      # TYPE IfcAreaDensityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcAreaMeasure = REAL;
      # END_TYPE;
      class IfcAreaMeasure < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_f
          rescue StandardError, TypeError => e
            print value << 'cannot be converted to an area: ' << e
          end
        end

        def step
          val = @value.to_s.upcase.gsub(/(\.)0+$/, '.')
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcBinary = BINARY;
      # END_TYPE;

      # TYPE IfcBoolean = BOOLEAN;
      # END_TYPE;
      class IfcBoolean < BaseType
        def initialize(ifc_model, value, long = false)
          super
          self.value = (value)
        end

        def value=(value)
          case value
          when NilClass, ''
            @value = nil
          when TrueClass, FalseClass
            @value = value
          else

            # see if casting it to a string makes it a boolean type
            case value.to_s.downcase
            when 'true'
              @value = true
            when 'false'
              @value = false
            else
              @value = nil
              IfcManager.add_export_message("IfcBoolean must be true or false, not #{value}")
            end
          end
        end

        def step
          case @value
          when TrueClass
            value = '.T.'
          when FalseClass
            value = '.F.'
          else
            return '$'
          end
          value = add_long(value) if @long
          value
        end

        def true?(obj)
          obj.to_s == 'true'
        end
      end

      # TYPE IfcBoxAlignment = IfcLabel;
      #  WHERE
      #   WR1 : SELF IN ['top-left', 'top-middle', 'top-right', 'middle-left', 'center', 'middle-right', 'bottom-left', 'bottom-middle', 'bottom-right'];
      # END_TYPE;

      # TYPE IfcCardinalPointReference = INTEGER;
      #  WHERE
      #   GreaterThanZero : SELF > 0;
      # END_TYPE;

      # TYPE IfcComplexNumber = ARRAY [1:2] OF REAL;
      # END_TYPE;

      # TYPE IfcCompoundPlaneAngleMeasure = LIST [3:4] OF INTEGER;
      #  WHERE
      #   MinutesInRange : ABS(SELF[2]) < 60;
      #   SecondsInRange : ABS(SELF[3]) < 60;
      #   MicrosecondsInRange : (SIZEOF(SELF) = 3) OR (ABS(SELF[4]) < 1000000);
      #   ConsistentSign : ((SELF[1] >= 0) AND (SELF[2] >= 0) AND (SELF[3] >= 0) AND ((SIZEOF(SELF) = 3) OR (SELF[4] >= 0)))
      # OR
      # ((SELF[1] <= 0) AND (SELF[2] <= 0) AND (SELF[3] <= 0) AND ((SIZEOF(SELF) = 3) OR (SELF[4] <= 0)));
      # END_TYPE;

      # TYPE IfcContextDependentMeasure = REAL;
      # END_TYPE;

      # TYPE IfcCountMeasure = NUMBER;
      # END_TYPE;
      class IfcCountMeasure < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_f
          rescue StandardError, TypeError => e
            print value << 'cannot be converted to a number: ' << e
          end
        end

        def step
          val = @value.to_s.upcase.gsub(/(\.)0+$/, '.')
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcCurvatureMeasure = REAL;
      # END_TYPE;

      # TYPE IfcDate = STRING;
      # END_TYPE;
      class IfcDate < BaseType
        def initialize(ifc_model, value, long = false)
          raise TypeError, "expected a Time, got #{value.class.name}" unless value.is_a?(DateTime)

          super
          @value = value
        end

        def step
          value = @value.strftime("'%Y-%m-%d'")
          value = add_long(value) if @long
          value
        end
      end

      # TYPE IfcDateTime = STRING;
      # END_TYPE;

      # TYPE IfcDayInMonthNumber = INTEGER;
      #  WHERE
      #   ValidRange : {1 <= SELF <= 31};
      # END_TYPE;

      # TYPE IfcDaylightSavingHour = INTEGER;
      #  WHERE
      #   WR1 : { 0 <= SELF <= 2 };
      # END_TYPE;

      # TYPE IfcDayInWeekNumber = INTEGER;
      #  WHERE
      #   ValidRange : {1 <= SELF <= 7};
      # END_TYPE;

      # TYPE IfcDescriptiveMeasure = STRING;
      # END_TYPE;

      # TYPE IfcDimensionCount = INTEGER;
      #  WHERE
      #   WR1 : { 0 < SELF <= 3 };
      # END_TYPE;

      # TYPE IfcDoseEquivalentMeasure = REAL;
      # END_TYPE;

      # TYPE IfcDuration = STRING;
      # END_TYPE;

      # TYPE IfcDynamicViscosityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricCapacitanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricChargeMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricConductanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricCurrentMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricResistanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcElectricVoltageMeasure = REAL;
      # END_TYPE;

      # TYPE IfcEnergyMeasure = REAL;
      # END_TYPE;

      # TYPE IfcFontStyle = STRING;
      #  WHERE
      #   WR1 : SELF IN ['normal','italic','oblique'];
      # END_TYPE;

      # TYPE IfcFontVariant = STRING;
      #  WHERE
      #   WR1 : SELF IN ['normal','small-caps'];
      # END_TYPE;

      # TYPE IfcFontWeight = STRING;
      #  WHERE
      #   WR1 : SELF IN ['normal','small-caps','100','200','300','400','500','600','700','800','900'];
      # END_TYPE;

      # TYPE IfcForceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcFrequencyMeasure = REAL;
      # END_TYPE;

      # TYPE IfcGloballyUniqueId = STRING(22) FIXED;
      # END_TYPE;

      # TYPE IfcHeatFluxDensityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcHeatingValueMeasure = REAL;
      #  WHERE
      #   WR1 : SELF > 0.;
      # END_TYPE;

      # TYPE IfcHourInDay = INTEGER;
      #  WHERE
      #   WR1 : { 0 <= SELF < 24 };
      # END_TYPE;

      # An identifier is an alphanumeric string which allows an individual
      #   thing to be identified. It may not provide natural-language meaning.
      #
      # TYPE IfcIdentifier = STRING(255);
      # END_TYPE;
      class IfcIdentifier < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = @value.to_s

            # IfcIdentifier may not be longer than 255 characters
            if @value.length > 255
              IfcManager.add_export_message('IfcIdentifier truncated to maximum of 255 characters')
              @value = @value[0..254]
            end
          rescue StandardError, TypeError => e
            print "Value cannot be converted to a String #{e}"
          end
        end

        # generate step object output string
        # adding long = true returns a full object string
        def step
          str_replace = Types.replace_char(@value)
          val = "'#{str_replace}'"
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcIlluminanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcInductanceMeasure = REAL;
      # END_TYPE;

      # A defined type of simple data type Integer. (Required since a select
      #   type, i.e. IfcSimpleValue, cannot include directly simple types in
      #   its select list).
      #
      # TYPE IfcInteger = INTEGER;
      # END_TYPE;
      class IfcInteger < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_i
          rescue StandardError, TypeError => e
            print value << 'cannot be converted to a Integer' << e
          end
        end

        def step
          val = @value.to_s
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcIntegerCountRateMeasure = INTEGER;
      # END_TYPE;

      # TYPE IfcIonConcentrationMeasure = REAL;
      # END_TYPE;

      # TYPE IfcIsothermalMoistureCapacityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcKinematicViscosityMeasure = REAL;
      # END_TYPE;

      # A label is the term by which something may be referred to.
      #   It is a string which represents the human-interpretable name of
      #   something and shall have a natural-language meaning.
      #
      # TYPE IfcLabel = STRING(255);
      # END_TYPE;
      class IfcLabel < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = @value.to_s

            # IfcLabel may not be longer than 255 characters
            if @value.length > 255
              IfcManager.add_export_message('IfcLabel truncated to maximum of 255 characters')
              @value = @value[0..254]
            end
          rescue StandardError, TypeError => e
            print "Value cannot be converted to a String #{e}"
          end
        end

        # generate step object output string
        # adding long = true returns a full object string
        def step
          str_replace = Types.replace_char(@value)
          val = "'#{str_replace}'"
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcLanguageId = IfcIdentifier;
      # END_TYPE;

      # A length measure is the value of a distance.
      #   Usually measured in millimeters (mm).
      #
      # TYPE IfcLengthMeasure = REAL;
      # END_TYPE;
      #
      # @param ifc_model
      # @param value
      # @param long [True, False] when False only the value is serialized instead of the full type
      # @param geometry [True, False] when set to False no geometry unit conversion is done
      class IfcLengthMeasure < IfcReal
        def initialize(ifc_model, value, long = false, geometry = true)
          super(ifc_model, value, long)
          @geometry = geometry
        end

        def mm
          @value = @value.mm
        end

        def cm
          @value = @value.cm
        end

        def m
          @value = @value.m
        end

        def km
          @value = @value.km
        end

        def inch
          @value = @value.inch
        end

        def feet
          @value = @value.feet
        end

        def yard
          @value = @value.yard
        end

        def mile
          @value = @value.mile
        end

        def convert
          case @ifc_model.units.length_unit
          when :Millimeter
            @value.to_mm
          when :Centimeter
            @value.to_cm
          when :Meter
            @value.to_m
          # when :Kilometer
          #   return @value.to_km
          when :Feet
            @value.to_feet
          # when :Mile
          #   return @value.to_mile
          when :Yard
            @value.to_yard
          else # default is :Inches
            @value
          end
        end

        def step
          if @geometry
            to_step_string(convert)
          else
            to_step_string(@value)
          end
        end
      end

      # TYPE IfcLineIndex = LIST [2:?] OF IfcPositiveInteger;
      # END_TYPE;

      # TYPE IfcLinearForceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLinearMomentMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLinearStiffnessMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLinearVelocityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLogical = LOGICAL;
      # END_TYPE;
      class Logical < BaseType
        attr_reader :value

        def initialize(value)
          @value = value.to_s
        end

        def step
          val = ".#{@value.upcase}."
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcLuminousFluxMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLuminousIntensityDistributionMeasure = REAL;
      # END_TYPE;

      # TYPE IfcLuminousIntensityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMagneticFluxDensityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMagneticFluxMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMassDensityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMassFlowRateMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMassMeasure = REAL;
      # END_TYPE;
      class IfcMassMeasure < BaseType
        def initialize(ifc_model, value, long = false)
          super
          @value = value.to_f
        end

        def step
          val = @value.to_s.upcase.gsub(/(\.)0+$/, '.')
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcMassPerLengthMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMinuteInHour = INTEGER;
      #  WHERE
      #   WR1 : {0 <= SELF <= 59 };
      # END_TYPE;

      # TYPE IfcModulusOfElasticityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcModulusOfLinearSubgradeReactionMeasure = REAL;
      # END_TYPE;

      # TYPE IfcModulusOfRotationalSubgradeReactionMeasure = REAL;
      # END_TYPE;

      # TYPE IfcModulusOfSubgradeReactionMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMoistureDiffusivityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMolecularWeightMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMomentOfInertiaMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMonetaryMeasure = REAL;
      # END_TYPE;

      # TYPE IfcMonthInYearNumber = INTEGER;
      #  WHERE
      #   ValidRange : {1 <= SELF <= 12};
      # END_TYPE;

      # TYPE IfcNonNegativeLengthMeasure = IfcLengthMeasure;
      #  WHERE
      #   NotNegative : SELF >= 0.;
      # END_TYPE;

      # TYPE IfcNumericMeasure = NUMBER;
      # END_TYPE;

      # TYPE IfcPHMeasure = REAL;
      #  WHERE
      #   WR21 : {0.0 <= SELF <= 14.0};
      # END_TYPE;

      # TYPE IfcParameterValue = REAL;
      # END_TYPE;
      class IfcParameterValue < IfcReal
      end

      # TYPE IfcPlanarForceMeasure = REAL;
      # END_TYPE;

      # A plane angle measure is the value of an angle in a plane.
      #   Usually measured in radian (rad, m/m = 1), but also grads may
      #   be used. The grad unit may be declared as a conversion based
      #   unit based on radian unit.
      #
      # TYPE IfcPlaneAngleMeasure = REAL;
      # END_TYPE;
      class IfcPlaneAngleMeasure < IfcReal
      end

      # TYPE IfcPositiveInteger = IfcInteger;
      #  WHERE
      #   WR1 : SELF > 0;
      # END_TYPE;

      # TYPE IfcPositiveLengthMeasure = IfcLengthMeasure;
      #  WHERE
      #   WR1 : SELF > 0.;
      # END_TYPE;
      #
      # A positive length measure is a length measure that is greater than zero.
      class IfcPositiveLengthMeasure < IfcLengthMeasure
        def initialize(ifc_model, value, long = false, geometry = true)
          super
          IfcManager.add_export_message('IfcPositiveLengthMeasure must be a positive number!') if @value <= 0
        end

        def step
          return nil if @value.zero?

          if @geometry
            to_step_string(convert)
          else
            to_step_string(@value)
          end
        end
      end

      # TYPE IfcPositivePlaneAngleMeasure = IfcPlaneAngleMeasure;
      #  WHERE
      #   WR1 : SELF > 0.;
      # END_TYPE;

      # TYPE IfcPositiveRatioMeasure = IfcRatioMeasure;
      #  WHERE
      #   WR1 : SELF > 0.;
      # END_TYPE;

      # TYPE IfcPowerMeasure = REAL;
      # END_TYPE;

      # TYPE IfcPresentableText = STRING;
      # END_TYPE;

      # TYPE IfcPressureMeasure = REAL;
      # END_TYPE;

      # TYPE IfcPropertySetDefinitionSet = SET [1:?] OF IfcPropertySetDefinition;
      # END_TYPE;

      # TYPE IfcRadioActivityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcRatioMeasure = REAL;
      # END_TYPE;
      class IfcRatioMeasure < IfcReal
      end

      # TYPE IfcNormalisedRatioMeasure = IfcRatioMeasure;
      #  WHERE
      #   WR1 : {0.0 <= SELF <= 1.0};
      # END_TYPE;
      class IfcNormalisedRatioMeasure < IfcRatioMeasure
        def initialize(ifc_model, value)
          super
          return unless @value < 0 || @value > 1

          raise 'Error creating IfcNormalisedRatioMeasure: Normalized ratio shall be a non-negative value less than or equal to 1.0'
        end
      end

      # TYPE IfcRotationalFrequencyMeasure = REAL;
      # END_TYPE;

      # TYPE IfcRotationalMassMeasure = REAL;
      # END_TYPE;

      # TYPE IfcRotationalStiffnessMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSecondInMinute = REAL;
      #  WHERE
      #   WR1 : { 0. <= SELF < 60. };
      # END_TYPE;

      # TYPE IfcSectionModulusMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSectionalAreaIntegralMeasure = REAL;
      # END_TYPE;

      # TYPE IfcShearModulusMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSolidAngleMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSoundPowerLevelMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSoundPowerMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSoundPressureLevelMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSoundPressureMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSpecificHeatCapacityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcSpecularExponent = REAL;
      # END_TYPE;

      # TYPE IfcSpecularRoughness = REAL;
      #  WHERE
      #   WR1 : {0.0 <= SELF <= 1.0};
      # END_TYPE;

      # TYPE IfcTemperatureGradientMeasure = REAL;
      # END_TYPE;

      # TYPE IfcTemperatureRateOfChangeMeasure = REAL;
      # END_TYPE;

      # TYPE IfcText = STRING;
      # END_TYPE;
      class IfcText < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_s
          rescue StandardError, TypeError => e
            puts "Value cannot be converted to a String: #{e}"
          end
        end

        def step
          str_replace = Types.replace_char(@value)
          val = "'#{str_replace}'"
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcTextAlignment = STRING;
      #  WHERE
      #   WR1 : SELF IN ['left', 'right', 'center', 'justify'];
      # END_TYPE;

      # TYPE IfcTextDecoration = STRING;
      #  WHERE
      #   WR1 : SELF IN ['none', 'underline', 'overline', 'line-through', 'blink'];
      # END_TYPE;

      # TYPE IfcTextFontName = STRING;
      # END_TYPE;

      # TYPE IfcTextTransformation = STRING;
      #  WHERE
      #   WR1 : SELF IN ['capitalize', 'uppercase', 'lowercase', 'none'];
      # END_TYPE;

      # TYPE IfcThermalAdmittanceMeasure = REAL;
      # END_TYPE;

      # TYPE IfcThermalConductivityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcThermalExpansionCoefficientMeasure = REAL;
      # END_TYPE;

      # TYPE IfcThermalResistanceMeasure = REAL;
      # END_TYPE;

      # IfcThermalTransmittanceMeasure is a measure of the rate at which energy is transmitted through a body.
      #   Usually measured in Watts/m2 Kelvin.
      #
      # TYPE IfcThermalTransmittanceMeasure = REAL;
      # END_TYPE;
      class IfcThermalTransmittanceMeasure < IfcReal
      end

      # TYPE IfcThermodynamicTemperatureMeasure = REAL;
      # END_TYPE;

      # TYPE IfcTime = STRING;
      # END_TYPE;

      # TYPE IfcTimeMeasure = REAL;
      # END_TYPE;

      # TYPE IfcTimeStamp = INTEGER;
      # END_TYPE;

      # TYPE IfcTorqueMeasure = REAL;
      # END_TYPE;

      # TYPE IfcURIReference = STRING;
      # END_TYPE;
      class IfcURIReference < BaseType
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_s
          rescue StandardError, TypeError => e
            puts "Value cannot be converted to a String: #{e}"
          end
        end

        def step
          str_replace = Types.replace_char(@value)
          val = "'#{str_replace}'"
          val = add_long(val) if @long
          val
        end
      end

      # TYPE IfcVaporPermeabilityMeasure = REAL;
      # END_TYPE;

      # TYPE IfcVolumeMeasure = REAL;
      # END_TYPE;
      class IfcVolumeMeasure < IfcReal
        def initialize(ifc_model, value, long = false)
          super
          begin
            @value = value.to_f
          rescue StandardError, TypeError => e
            puts value << 'cannot be converted to a volume: ' << e
          end
        end

        def step
          val = @value.to_s.upcase.gsub(/(\.)0+$/, '.')
          val = add_long(val) if @long
          val
        end
      end

      # IfcVolumetricFlowRateMeasure is a measure of the volume of a medium flowing per unit time.
      #   Usually measured in m3/s.
      #   Type: REAL
      #
      # TYPE IfcVolumetricFlowRateMeasure = REAL;
      # END_TYPE;
      class IfcVolumetricFlowRateMeasure < IfcReal
      end

      # TYPE IfcWarpingConstantMeasure = REAL;
      # END_TYPE;

      # TYPE IfcWarpingMomentMeasure = REAL;
      # END_TYPE;

      # TYPE IfcYearNumber = INTEGER;
      # END_TYPE;

      class PEnum_ElementStatus
        def initialize(ifc_model, value, long = true)
          @value = value
        end

        def step
          @value
        end
      end

    end
  end
end
