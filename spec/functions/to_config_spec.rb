# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::to_config' do
  it { is_expected.to run.with_params({}).and_return("# Managed by Puppet\n") }

  it 'writes the options in alphabetical order' do
    is_expected.to run.with_params('LogRotate' => true, 'LogFileMaxSize' => '10M', 'DatabaseDirectory' => '/var/lib/clamav')
                      .and_return("# Managed by Puppet\nDatabaseDirectory /var/lib/clamav\nLogFileMaxSize 10M\nLogRotate yes\n")
  end

  it 'writes booleans as yes and no' do
    is_expected.to run.with_params('ScanPDF' => true, 'ScanHTML' => false).and_return("# Managed by Puppet\nScanHTML no\nScanPDF yes\n")
  end

  it 'writes integers' do
    is_expected.to run.with_params('MaxThreads' => 4, 'TCPSocket' => 3310).and_return("# Managed by Puppet\nMaxThreads 4\nTCPSocket 3310\n")
  end

  it 'keeps the values as they are' do
    is_expected.to run.with_params('RejectMsg' => 'Infected by %v: "rejected"', 'OnInfected' => 'Reject')
                      .and_return(%(# Managed by Puppet\nOnInfected Reject\nRejectMsg Infected by %v: "rejected"\n))
  end

  it 'repeats an option once per value of an array' do
    is_expected.to run.with_params('ExcludePath' => ['^/proc/', '^/sys/'], 'TCPAddr' => ['127.0.0.1'], 'LocalNet' => ['local', 8])
                      .and_return("# Managed by Puppet\nExcludePath ^/proc/\nExcludePath ^/sys/\nLocalNet local\nLocalNet 8\nTCPAddr 127.0.0.1\n")
  end

  it 'leaves out the undef options' do
    is_expected.to run.with_params('LogSyslog' => nil, 'User' => 'clamav').and_return("# Managed by Puppet\nUser clamav\n")
  end

  it { is_expected.to run.with_params('User' => "clamav\nLogSyslog yes").and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('# Comment' => 'yes').and_raise_error(ArgumentError) }
  it { is_expected.to run.with_params('ExcludePath' => []).and_raise_error(ArgumentError) }
end
