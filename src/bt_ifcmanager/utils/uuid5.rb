# frozen_string_literal: true

#  uuid5.rb
#
#  Copyright 2025 Jan Brouwer <jan@brewsky.nl>
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
#  This code is adapted from the UUIDTools library:
#  https://github.com/sporkmonger/uuidtools/blob/main/lib/uuidtools.rb
#

require 'digest/sha1'

module BimTools
  module IfcManager
    module Utils
      ##
      # Creates a new UUID (version 5) from a SHA1 hash
      #
      # @param [String] namespace The namespace string
      # @param [String] name The name to hash
      # @return [String] The generated UUID
      def self.create_uuid5(namespace, name)
        version = 5
        hash = Digest::SHA1.new
        hash.update(namespace) # Use the namespace string directly
        hash.update(name)

        # Extract the first 32 characters of the hash
        hash_string = hash.hexdigest[0..31]

        # Format the UUID string
        uuid_string = "#{hash_string[0..7]}-#{hash_string[8..11]}-" +
                      "#{hash_string[12..15]}-#{hash_string[16..19]}-" +
                      "#{hash_string[20..31]}"

        # Set the version and variant bits
        uuid_string[14] = version.to_s(16) # Set version
        uuid_string[19] = ((uuid_string[19].to_i(16) & 0x3) | 0x8).to_s(16) # Set variant

        uuid_string
      end
    end
  end
end
