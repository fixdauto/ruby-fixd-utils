# frozen_string_literal: true

require_relative "fixd_utils/version"

require_relative "fixd_utils/base_32"
require_relative "fixd_utils/network_error"
require_relative "fixd_utils/uri_builder"
# require_relative "fixd_utils/data_struct"
# require_relative "fixd_utils/global_lock"

module FixdUtils
  class Error < StandardError; end
  # Your code goes here...
end
