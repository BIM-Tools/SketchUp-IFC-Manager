module BimTools
  module TransformationHelper
    def self.strip_scaling(transformation)
      t = transformation
      axis_fix = if t.xaxis.cross(t.yaxis).samedirection?(t.zaxis)
                   Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 1])
                 else
                   Geom::Transformation.axes([0, 0, 0], [1, 0, 0], [0, -1, 0], [0, 0, 1])
                 end

      t = transformation.to_a
      x = t[0..2].normalize # is the xaxis
      y = t[4..6].normalize # is the yaxis
      z = t[8..10].normalize # is the zaxis
      no_scale = Geom::Transformation.axes(transformation.origin, x, y, z) * axis_fix.inverse
      # scaling = Geom::Transformation.scaling(t[0..2].length, t[4..6].length, t[8..10].length) * axis_fix
      scaling = transformation * no_scale.inverse
      [no_scale, scaling]
    end
  end
end
