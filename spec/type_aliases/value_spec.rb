# frozen_string_literal: true

require 'spec_helper'

describe 'Clamav::Value' do
  it { is_expected.to allow_values(true, false, 0, 3310, '/run/clamav/clamd.ctl', '25M', 'Message rejected: %v', ['^/proc/'], ['local', '192.0.2.0/24', 3310]) }
  it { is_expected.not_to allow_values(nil, '', "a\nb", "a\r", [], [true], [''], [nil], 1.5, { 'a' => 'b' }) }
end
