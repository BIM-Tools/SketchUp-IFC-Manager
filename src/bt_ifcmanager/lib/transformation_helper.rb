module BimTools
  # Provides helper methods for transformations.
  module TransformationHelper
    # Decomposes a transformation into a rotation + translation, and scaling components.
    #
    # @param transformation [Geom::Transformation] The transformation to decompose.
    # @return [Array<Geom::Transformation>] An array containing the rotation + translation transformation, and the scaling transformation.
    def self.decompose_transformation(transformation)
      matrix = transformation.to_a

      # Extract translation vector from the last column of the matrix.
      translation_vector = Geom::Vector3d.new(matrix[12], matrix[13], matrix[14])
      translation = Geom::Transformation.translation(translation_vector)

      # Extract scaling factors from the lengths of the matrix's columns.
      x_axis = Geom::Vector3d.new(matrix[0], matrix[1], matrix[2])
      y_axis = Geom::Vector3d.new(matrix[4], matrix[5], matrix[6])
      z_axis = Geom::Vector3d.new(matrix[8], matrix[9], matrix[10])

      scale_x = x_axis.length
      scale_y = y_axis.length
      scale_z = z_axis.length

      # Check if the transformation is flipped.
      is_flipped_x = y_axis.cross(z_axis).samedirection?(x_axis)
      is_flipped_y = x_axis.cross(y_axis).samedirection?(z_axis)
      is_flipped_z = z_axis.cross(x_axis).samedirection?(y_axis)

      # Adjust the scaling factors if the transformation is flipped.
      scale_x = -scale_x unless is_flipped_x
      scale_y = -scale_y unless is_flipped_y
      scale_z = -scale_z unless is_flipped_z

      # Calculate the rotation by normalizing the original matrix columns.
      rotation_matrix = [
        x_axis.x / scale_x, x_axis.y / scale_x, x_axis.z / scale_x, 0,
        y_axis.x / scale_y, y_axis.y / scale_y, y_axis.z / scale_y, 0,
        z_axis.x / scale_z, z_axis.y / scale_z, z_axis.z / scale_z, 0,
        0, 0, 0, 1
      ]
      rotation = Geom::Transformation.new(rotation_matrix)

      rotation_and_translation = translation * rotation
      scaling_and_reflection = Geom::Transformation.scaling(scale_x, scale_y, scale_z) # Geom::Transformation.new # transformation * rotation_and_translation.inverse

      [rotation_and_translation, scaling_and_reflection]
    end
  end
end
