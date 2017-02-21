module SKUI
  # @since 1.0.0
  class Background

    attr_accessor( :color, :image, :position, :repeat )
    
    # @param [String] color
    # @param [Integer, Nil] image
    # @param [Boolean, Nil] position
    # @param [Boolean, Nil] repeat
    #
    # @since 1.0.0
    def initialize( color = nil, image = nil, position = nil, repeat = nil )
      @color = color
      @image = image
      @position = position
      @repeat = repeat
      puts @color
    end

    # @return [String]
    # @since 1.0.0
    def to_js
      properties = JSON.new
      properties['background-color']    = @color    if @color
      properties['background-image']    = @image    if @image
      properties['background-position'] = @position if @position
      properties['background-repeat']   = @repeat   if @repeat
      puts properties.to_s
    end

  end # class
end # module
