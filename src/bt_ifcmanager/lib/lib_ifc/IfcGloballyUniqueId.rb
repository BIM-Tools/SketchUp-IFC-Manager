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
 
  class IfcGloballyUniqueId
   
    # possible characters in GUID
    GUID64 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'
    
    def initialize( sketchup = nil )
      @sketchup = sketchup
      
      # if sketchup object has a GUID, then use that, otherwise create new
      if @sketchup && defined?( @sketchup.guid )
        @hex_guid = unformat_guid( @sketchup.guid )
      else
        @hex_guid = new_guid
      end
    end
    
    def set_parent_guid( parent_hex_guid )
      @hex_guid = combined_guid( @hex_guid, parent_hex_guid )
    end # def set_parent
    
    # return IfcGloballyUniqueId within quotes
    def step()
      return hex_to_ifc_guid( @hex_guid )
    end # def step
    
    def to_s()
      return @hex_guid
    end # def to_s
    
    # recognize guid type and reformat to unformatted hex version
    def unformat_guid( guid )
      
      # check if ifc_guid(length is 22) or uuid
      if guid.length == 22
        guid = ifc_guid_to_hex( guid )
      else
      
        # tr('-', ''): removes the dashes from the hex string
        guid.tr('-', '')
      end
    end # def unformat_guid
    
    # combine guid with parent guid
    def combined_guid( sketchup_guid, parent_guid )
      guid = (sketchup_guid.to_i(16) ^ parent_guid.to_i(16)).to_s(16).rjust(32, '0')
      
      # The digit at position 1 above is always "4"
      # set the four most significant bits of the 7th byte to 0100'B, so the high nibble is "4"
      guid[12] = "4"
      
      # and the digit at position 2 is always one of "8", "9", "A" or "B".
      # set the two most significant bits of the 9th byte to 10'B, so the high nibble will be one of "8", "9", "A", or "B".
      h_val = guid[16]
      b_val = [h_val].pack('H*').unpack('B*')[0]
      b_val[0] = "1"
      b_val[1] = "0"
      guid[16] = [b_val].pack('B*').unpack('H*')[0]
      return guid
    end # def combined_guid
    
    # convert IfcGloballyUniqueId into unformatted hex number
    def ifc_guid_to_hex( ifc_guid )
      bin = ""
      length = 2
      ifc_guid.each_char do | char |
        n = GUID64.index( char.to_s )
        bin = bin +  n.to_s( 2 ).rjust( length, "0" )
        length = 6
      end
      return [bin].pack('B*').unpack('H*')[0]
    end # def ifc_guid_to_hex
    
    # # convert IfcGloballyUniqueId into UUID
    # def ifc_guid_to_uuid( ifc_guid )
      # return ifc_guid_to_hex( ifc_guid ).insert(20, '-').insert(16, '-').insert(12, '-').insert(8, '-')
    # end # def ifc_guid_to_uuid
    
    # convert unformatted hex number into IfcGloballyUniqueId
    def hex_to_ifc_guid( hex_guid )
      ifc_guid = ""
      
      # https://www.cryptosys.net/pki/uuid-rfc4122.html 
      # pack('H*'): converts the hex string to a binary number (high nibble first)
      # unpack('B*'): converts the binary number to a bit string (128 0's and 1's) and places it into an array (Most Significant Block first)
      # [0]: gets the first (and only) value from the array
      bit_string = [hex_guid].pack('H*').unpack('B*')[0].to_s
      
      # take the number (0 - 63) and find the matching character in guid64, add the found character to the guid string
      # start with the 2 leftover bits
      char_num = bit_string[0,2].to_i(2)
      ifc_guid << GUID64[char_num]
      block_counter = 2
      while block_counter < 128  do
        char_num = bit_string[ block_counter, 6 ].to_i( 2 )
        ifc_guid << GUID64[char_num]
        block_counter += 6
      end
      return "'#{ifc_guid}'"
    end # def hex_to_ifc_guid
    
    def new_guid
      
      # Old method: faster, but not a correct IfcGloballyUniqueId, just a random number
      # the leading 0 is added because the first character is only 1 bit and can only contain a 0,1,2 or 3.
      # while all other characters are 6 bits (64 possible values)
      #guid = '';21.times{|i|guid<<'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'[rand(64)]}
      #first = rand(0...3).to_s
      #guid = "#{first}#{guid}"
      
      # SecureRandom.uuid: creates a 128 bit UUID hex string
      # convert to hex
      return unformat_guid( SecureRandom.uuid )
    end
  end # class IfcGloballyUniqueId
 end # module IfcManager
end # module BimTools
