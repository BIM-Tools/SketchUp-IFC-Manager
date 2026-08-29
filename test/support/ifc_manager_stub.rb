# frozen_string_literal: true

# Purpose: minimal BimTools::IfcManager hooks so pure lib_ifc files load without SketchUp

require 'set'
require 'date'

module BimTools
  module IfcManager
    @export_messages = []

    def self.export_messages
      @export_messages
    end

    def self.add_export_message(message)
      @export_messages << message
    end

    def self.reset_export_messages
      @export_messages = []
    end
  end
end
