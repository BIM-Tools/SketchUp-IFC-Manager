# frozen_string_literal: true

#  geo_coordinate_calculator.rb
#
#  Copyright 2026 joaogaspar-bim
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
    # Pure geodesy/coordinate math shared between the actual IFC
    # georeference export (IfcMapConversionBuilder, IfcProjectedCRSBuilder,
    # GeolocationBuilder) and the read-only preview in the settings dialog.
    #
    # Every method here returns plain Ruby numbers/strings - no IFC entity
    # or type wrapping - so it can be used without an IfcModel.
    module GeoCoordinateCalculator
      module_function

      # Same transformation IfcModel#initialize ends up feeding into
      # GeolocationBuilder#setup_geolocation (world_transformation.inverse,
      # applied to a world_transformation that is itself already inverted
      # when model_axes is used - the two inversions cancel out).
      #
      # @param model [Sketchup::Model]
      # @param use_model_axes [Boolean] matches the 'model_axes' export option
      # @return [Geom::Transformation]
      def world_transformation(model, use_model_axes)
        return model.axes.transformation if use_model_axes

        Geom::Transformation.new
      end

      # @param utm_point [UTMPoint]
      # @return [Array(String, String)] [epsg_name, epsg_description]
      def epsg_for_utm(utm_point)
        zone_number = utm_point.zone_number
        zone_letter = utm_point.zone_letter
        hemisphere = zone_letter >= 'N' ? 'N' : 'S'
        zone_code = hemisphere == 'N' ? 32_600 : 32_700
        epsg_code = zone_code + zone_number.to_i
        epsg_name = "EPSG:#{epsg_code}"
        epsg_description = "#{epsg_name} - WGS 84 / UTM zone #{zone_number}#{hemisphere}"

        [epsg_name, epsg_description]
      end

      # Combines a UTM point (of the SketchUp-internal model origin) with the
      # world transformation to get the final IfcMapConversion values - the
      # exact computation used by IfcMapConversionBuilder#set_from_utm.
      #
      # @param utm_point [UTMPoint]
      # @param world_transformation [Geom::Transformation]
      # @return [Hash] :eastings, :northings, :xaxisabscissa, :xaxisordinate (meters)
      def map_conversion_values(utm_point, world_transformation)
        hemisphere = utm_point.zone_letter >= 'N' ? 'N' : 'S'
        utm_y = utm_point.y
        utm_x = utm_point.x
        equator_height = 10_000_000

        # Adjust the y value if the hemisphere is south
        utm_y = 2 * equator_height - utm_y if hemisphere == 'S'

        utm_transformation = Geom::Transformation.translation([utm_x.m, utm_y.m, 0])
        transformation = utm_transformation * world_transformation
        origin = transformation.origin
        xaxis = transformation.xaxis

        {
          eastings: origin.x.to_m,
          northings: origin.y.to_m,
          xaxisabscissa: xaxis.x,
          xaxisordinate: xaxis.y
        }
      end

      # Decimal degrees -> [degrees, minutes, seconds, millionths], same
      # breakdown IfcSite_su#convert_to_compound_plane_angle_measure writes
      # into RefLatitude/RefLongitude.
      #
      # @param decimal_degrees [Float]
      # @return [Array(Integer, Integer, Integer, Integer)]
      def to_dms(decimal_degrees)
        degrees = decimal_degrees.to_i
        minutes = ((decimal_degrees - degrees) * 60).to_i
        seconds = (((decimal_degrees - degrees) * 60 - minutes) * 60).to_i
        millionths = ((((decimal_degrees - degrees) * 60 - minutes) * 60 - seconds) * 1_000_000).to_i

        [degrees, minutes, seconds, millionths]
      end

      # Sketchup::Model#point_to_latlong ignores the Z coordinate entirely -
      # confirmed both by the SketchUp API issue tracker ("LatLong and UTM
      # conversion ignores the Z coordinate", api-issue-tracker#412) and
      # empirically against a real model here: a model with a verified 750m
      # geo-location elevation still had point_to_latlong(...).z come out at
      # ~0. There is no documented API for model elevation; the only way
      # (also used by this fork before commit ef20990, and confirmed against
      # that same 750m model) is the undocumented 'ModelTranslationZ' key of
      # the 'GeoReference' attribute dictionary - the model's SketchUp-native
      # origin height, in inches, sign-flipped relative to elevation.
      #
      # @param geo_reference [Sketchup::AttributeDictionary] su_model.attribute_dictionary('GeoReference')
      # @return [Float, nil] elevation in meters, nil when the key is absent
      def elevation_from_geo_reference(geo_reference)
        return nil unless geo_reference

        raw = geo_reference['ModelTranslationZ']
        return nil unless raw

        (-raw).to_m
      end

      # Computes every value that ends up in the exported IFC georeference
      # (IfcSite RefLatitude/RefLongitude/RefElevation and IfcMapConversion
      # Eastings/Northings/OrthogonalHeight) from the SketchUp model's
      # current geo-location - without needing a full IfcModel/export run.
      #
      # @param model [Sketchup::Model]
      # @param use_model_axes [Boolean] matches the 'model_axes' export option
      # @return [Hash, nil] nil when the model has no geo-location set
      def preview(model, use_model_axes)
        return nil unless model
        return nil unless model.georeferenced?

        geo_reference = model.attribute_dictionary('GeoReference')
        return nil unless geo_reference

        transformation = world_transformation(model, use_model_axes)

        # point_to_latlong returns x=longitude, y=latitude - its z is NOT
        # elevation, see #elevation_from_geo_reference
        latlong_point = model.point_to_latlong(transformation.origin)
        utm_point = model.point_to_utm(Geom::Point3d.new)
        epsg_name, epsg_description = epsg_for_utm(utm_point)
        map_conversion = map_conversion_values(utm_point, transformation)

        {
          latitude: latlong_point.y,
          longitude: latlong_point.x,
          elevation: elevation_from_geo_reference(geo_reference),
          epsg_name: epsg_name,
          epsg_description: epsg_description,
          eastings: map_conversion[:eastings],
          northings: map_conversion[:northings]
        }
      end
    end
  end
end
