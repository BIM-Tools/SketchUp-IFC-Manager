# frozen_string_literal: true

#  classification_dict_filters.rb
#
#  Copyright 2026 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
  module IfcManager
    # Sub-attribute-dictionary names that describe a classification's own
    # bookkeeping (its assigned code/name/location, not a set of exported
    # properties) - shared between EntityDictionaryReader (which decides what
    # to export) and Settings (which discovers what property-set groups exist
    # for a classification, to offer as a per-group export toggle), so both
    # agree on what counts as an exportable property-set group.
    CLASSIFICATION_METADATA_ATTRIBUTES = %w[
      Location
      ItemReference
      Identification
      Name
      ReferencedSource
      Description
      Sort
      Definition
      RelatedIfcEntityNames
    ].freeze
  end
end
