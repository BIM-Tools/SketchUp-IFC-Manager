module SKUI

  require File.join( PATH, 'control.rb' )


  # @since 1.0.0
  class Autolist < Control

    # @return [Array<String>]
    # @since 1.0.0
    prop_reader( :items )

    # @return [String]
    # @since 1.0.0
    prop_writer( :value, &TypeCheck::STRING )

    # @return [Boolean]
    # @since 1.0.0
    prop_bool( :multiline, &TypeCheck::BOOLEAN )

    # @return [Boolean]
    # @since 1.0.0
    prop_bool( :readonly, &TypeCheck::BOOLEAN )

    # @return [Boolean]
    # @since 1.0.0
    prop_bool( :password, &TypeCheck::BOOLEAN )

    # @since 1.0.0
    define_event( :change )
    define_event( :textchange )
    define_event( :keydown, :keypress, :keyup )
    define_event( :focus, :blur )
    define_event( :copy, :cut, :paste )

    # @param [Array<String>] list
    #
    # @since 1.0.0
    def initialize( list = [] )
      unless list.is_a?( Array )
        raise( ArgumentError, 'Not an array.' )
      end
      # (?) Check for String content? Convert to strings? Accept #to_a objects?
      super()
       # (?) Should the :items list be a Hash instead? To allow key/value pairs.
      @properties[ :items ] = list.dup
    end

    # @return [String]
    # @since 1.0.0
    def value
      data = window.bridge.get_value( "##{ui_id} input, ##{ui_id} textarea" )
      @properties[ :value ] = data
      data
    end
    
    def id()
      return "#" + ui_id + "_ui"
    end
    
    def items=( list = [] )
      unless list.is_a?( Array )
        raise( ArgumentError, 'Not an array.' )
      end
      window.bridge.call( 'UI.Autolist.update_items', ui_id, list )
      @properties[ :items ] = list.dup
    end

  end # class
end # module
