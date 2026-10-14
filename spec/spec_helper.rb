# frozen_string_literal: true

require 'voxpupuli/test/spec_helper'

RSpec.configure do |c|
  c.facterdb_string_keys = false
end

add_mocked_facts!

Dir['./spec/support/spec/**/*.rb'].sort.each { |f| require f }
