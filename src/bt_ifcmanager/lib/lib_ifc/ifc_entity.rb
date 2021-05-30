require_relative(File.join('.', 'step.rb'))
module BimTools
 module IFC2X3
  class IfcEntity
    include Step
    def initialize( ifc_model, sketchup=nil, *args )
      @ifc_model = ifc_model
    end
    def self.attributes()
      []
    end
  end
 end
end