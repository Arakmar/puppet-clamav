# frozen_string_literal: true

require 'spec_helper'

describe 'Clamav::Options' do
  it { is_expected.to allow_values({}, { 'LocalSocket' => '/run/clamav/clamd.ctl', 'MaxThreads' => 4, 'OLE2BlockMacros' => false }, { 'LogSyslog' => nil }) }
  it { is_expected.not_to allow_values({ 'localSocket' => 'x' }, { 'Local Socket' => 'x' }, { '# comment' => 'x' }, { 'Log_File' => 'x' }, { '' => 'x' }, { 'User' => '' }) }
end
