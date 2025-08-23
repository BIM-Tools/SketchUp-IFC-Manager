# frozen_string_literal: true

#  IfcGloballyUniqueId.rb
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

# (!) Note: securerandom takes very long to load
require 'securerandom'

module BimTools
  module IfcManager
    # Generate a GlobalId optionally based on sketchup ComponentInstance
    #
    # @param [Sketchup::ComponentInstance] sketchup (OPTIONAL)
    class IfcGloballyUniqueId
      # possible characters in GUID
      GUID64 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'

      def initialize(ifc_model = nil, instance_path = nil)
        if ifc_model && instance_path
          uuid = ifc_model.project_data.get_attribute('uuid', instance_path)
          unless uuid
            uuid = SecureRandom.uuid
            ifc_model.project_data.set_attribute('uuid', instance_path, uuid)
          end
          @hex_guid = unformat_guid(uuid)
        else
          @hex_guid = new_guid
        end
      end

      # return IfcGloballyUniqueId within quotes
      def step
        "'#{self}'"
      end

      # get unformatted hex number
      def to_hex
        @hex_guid
      end

      # convert unformatted hex number into IfcGloballyUniqueId
      def to_s
        ifc_guid = +''

        # https://www.cryptosys.net/pki/uuid-rfc4122.html
        # pack('H*'): converts the hex string to a binary number (high nibble first)
        # unpack('B*'): converts the binary number to a bit string (128 0's and 1's) and places it into an array (Most Significant Block first)
        # [0]: gets the first (and only) value from the array
        bit_string = [@hex_guid].pack('H*').unpack('B*')[0].to_s

        # take the number (0 - 63) and find the matching character in guid64, add the found character to the guid string
        # start with the 2 leftover bits
        char_num = bit_string[0, 2].to_i(2)
        ifc_guid << GUID64[char_num]
        block_counter = 2
        while block_counter < 128
          char_num = bit_string[block_counter, 6].to_i(2)
          ifc_guid << GUID64[char_num]
          block_counter += 6
        end
        ifc_guid.to_s
      end

      # Get sketchup guid including persistent_id
      # added persistent_id as workaround for duplicate guids in Sketchup
      def get_sketchup_hex_guid(sketchup)
        # if defined?(sketchup.persistent_id)
        #   (unformat_guid(sketchup.guid).to_i(16) ^ sketchup.persistent_id).to_s(16).rjust(32, '0')
        # else
        unformat_guid(sketchup.guid)
        # end
      end

      # recognize guid type (IFC or UUID) and reformat to unformatted hex version without dashes
      def unformat_guid(guid)
        if guid.length == 22
          guid = ifc_guid_to_hex(guid)
        else
          guid.tr('-', '')
        end
      end

      # convert IfcGloballyUniqueId into unformatted hex number
      def ifc_guid_to_hex(ifc_guid)
        bin = +''
        length = 2
        ifc_guid.each_char do |char|
          n = GUID64.index(char.to_s)
          bin <<= n.to_s(2).rjust(length, '0')
          length = 6
        end
        [bin].pack('B*').unpack('H*')[0]
      end

      # convert IfcGloballyUniqueId into UUID
      def to_uuid
        raise "Invalid GUID length: #{@hex_guid.length}. Expected 32 characters." unless @hex_guid.length == 32

        @hex_guid.dup.insert(20, '-').insert(16, '-').insert(12, '-').insert(8, '-')
      end

      def new_guid
        # Old method: faster, but not a correct IfcGloballyUniqueId, just a random number
        # the leading 0 is added because the first character is only 1 bit and can only contain a 0,1,2 or 3.
        # while all other characters are 6 bits (64 possible values)
        # guid = '';21.times{|i|guid<<'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'[rand(64)]}
        # first = rand(0...3).to_s
        # guid = "#{first}#{guid}"

        # SecureRandom.uuid: creates a 128 bit UUID hex string
        # convert to hex
        unformat_guid(SecureRandom.uuid)
      end

      # return the UUID without dashes
      def ifcx
        to_uuid
      end
    end
  end
end
