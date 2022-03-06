require 'delegate'
require 'singleton'
require 'tempfile'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'zlib'
require_relative 'zip/dos_time'
require_relative 'zip/ioextras'
require 'rbconfig'
require_relative 'zip/entry'
require_relative 'zip/extra_field'
require_relative 'zip/entry_set'
require_relative 'zip/central_directory'
require_relative 'zip/file'
require_relative 'zip/input_stream'
require_relative 'zip/output_stream'
require_relative 'zip/decompressor'
require_relative 'zip/compressor'
require_relative 'zip/null_decompressor'
require_relative 'zip/null_compressor'
require_relative 'zip/null_input_stream'
require_relative 'zip/pass_thru_compressor'
require_relative 'zip/pass_thru_decompressor'
require_relative 'zip/crypto/encryption'
require_relative 'zip/crypto/null_encryption'
require_relative 'zip/crypto/traditional_encryption'
require_relative 'zip/inflater'
require_relative 'zip/deflater'
require_relative 'zip/streamable_stream'
require_relative 'zip/streamable_directory'
require_relative 'zip/constants'
require_relative 'zip/errors'

module BimTools
 module Zip
  extend self
  attr_accessor :unicode_names,
                :on_exists_proc,
                :continue_on_exists_proc,
                :sort_entries,
                :default_compression,
                :write_zip64_support,
                :warn_invalid_date,
                :case_insensitive_match,
                :force_entry_names_encoding,
                :validate_entry_sizes

  def reset!
    @_ran_once = false
    @unicode_names = false
    @on_exists_proc = false
    @continue_on_exists_proc = false
    @sort_entries = false
    @default_compression = ::Zlib::DEFAULT_COMPRESSION
    @write_zip64_support = false
    @warn_invalid_date = true
    @case_insensitive_match = false
    @validate_entry_sizes = false
  end

  def setup
    yield self unless @_ran_once
    @_ran_once = true
  end

  reset!
 end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
