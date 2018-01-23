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

require 'securerandom'

module BimTools
 module IfcManager
  def new_guid
    
    # Old method: faster, but not a correct IfcGloballyUniqueId, just a random number
    # the leading 0 is added because the first character is only 1 bit and can only contain a 0,1,2 or 3.
    # while all other characters are 6 bits (64 possible values)
    guid = '';21.times{|i|guid<<'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'[rand(64)]}
    first = rand(0...3).to_s
    guid = "#{first}#{guid}"
    
    # possible characters in GUID
    #guid64 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'
    #guid = ""
    
    # SecureRandom.uuid: creates a 128 bit UUID hex string
    # tr('-', ''): removes the dashes from the hex string
    # pack('H*'): converts the hex string to a binary number (high nibble first) (?) is this correct?
    #   This reverses the number so we end up with the leftover bit on the end, which helps with chopping the sting into pieces.
    #   It needs to be reversed again to end up with a string in the original order.
    # unpack('b*'): converts the binary number to a bit string (128 0's and 1's) and places it into an array
    # [0]: gets the first (and only) value from the array
    # to_s.scan(/.{1,6}/m): chops the string into pieces 6 characters(bits) with the leftover on the end.
    #[SecureRandom.uuid.tr('-', '')].pack('H*').unpack('b*')[0].to_s.scan(/.{1,6}/m).each do |num|
    #
    #  # take the number (0 - 63) and find the matching character in guid64, add the found character to the guid string
    #  guid << guid64[num.to_i(2)]
    #end
    #guid.reverse!
    return "'#{guid}'"
    #return guid
  end
 end # module IfcManager
end # module BimTools
