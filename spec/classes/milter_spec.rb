# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::milter' do
  # The clamav-milter.conf of the Debian 13 package, without
  # TemporaryDirectory which clamav-milter ignores
  debian_options = {
    'MilterSocket' => '/var/run/clamav/clamav-milter.ctl', 'FixStaleSocket' => true, 'User' => 'clamav', 'ReadTimeout' => 120,
    'Foreground' => false, 'PidFile' => '/var/run/clamav/clamav-milter.pid', 'ClamdSocket' => 'unix:/var/run/clamav/clamd.ctl',
    'OnClean' => 'Accept', 'OnInfected' => 'Quarantine', 'OnFail' => 'Defer', 'AddHeader' => 'Replace', 'LogSyslog' => false,
    'LogFacility' => 'LOG_LOCAL6', 'LogVerbose' => false, 'LogInfected' => 'Off', 'LogClean' => 'Off', 'LogRotate' => true,
    'MaxFileSize' => '25M', 'SupportMultipleRecipients' => false, 'LogFile' => '/var/log/clamav/clamav-milter.log', 'LogTime' => true,
    'LogFileUnlock' => false, 'LogFileMaxSize' => '1M', 'MilterSocketGroup' => 'clamav', 'MilterSocketMode' => '666'
  }

  context 'validated by ClamAV' do
    it 'rejects an unknown option' do
      expect(expect_valid_for_clamav('milter', "MilterSocket /run/milter.sock\nUnknownOption yes\n", valid: false)).to match(%r{Unknown option UnknownOption})
    end
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      expected = {
        'Archlinux' => {
          package: nil,
          service: false,
          config_file: '/etc/clamav/clamav-milter.conf',
          content: <<~CONF,
            # Managed by Puppet
            ClamdSocket unix:/run/clamav/clamd.ctl
            LogFile /var/log/clamav/clamav-milter.log
            LogTime yes
            MilterSocket /run/clamav/clamav-milter.sock
            MilterSocketGroup clamav
            MilterSocketMode 660
            PidFile /run/clamav/clamav-milter.pid
            User clamav
          CONF
        },
        'Debian' => {
          package: 'clamav-milter',
          service: true,
          config_file: '/etc/clamav/clamav-milter.conf',
          content: <<~CONF,
            # Managed by Puppet
            ClamdSocket unix:/run/clamav/clamd.ctl
            FixStaleSocket yes
            LogFile /var/log/clamav/clamav-milter.log
            LogTime yes
            MilterSocket /run/clamav/clamav-milter.ctl
            MilterSocketGroup clamav
            MilterSocketMode 666
            PidFile /run/clamav/clamav-milter.pid
            User clamav
          CONF
        },
        'RedHat' => {
          package: 'clamav-milter',
          service: true,
          config_file: '/etc/mail/clamav-milter.conf',
          content: <<~CONF,
            # Managed by Puppet
            ClamdSocket unix:/run/clamd.scan/clamd.sock
            FixStaleSocket yes
            LogSyslog yes
            MilterSocket /run/clamav-milter/clamav-milter.socket
            MilterSocketGroup clamilt
            MilterSocketMode 660
            PidFile /run/clamav-milter/clamav-milter.pid
            User clamilt
          CONF
        },
      }.fetch(os_facts[:os]['family'])
      config_file = expected[:config_file]

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('clamav') }

        it do
          is_expected.to contain_file(config_file)
            .with_ensure('file')
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
            .with_content(expected[:content])
            .with_validate_cmd(nil)
            .that_requires('Class[clamav::install]')
        end

        if expected[:service]
          it { is_expected.to contain_service('clamav-milter').with_ensure('running').with_enable(true).that_subscribes_to("File[#{config_file}]") }
        else
          it { is_expected.not_to contain_service('clamav-milter') }
        end

        if expected[:package]
          it { is_expected.to contain_package(expected[:package]).with_ensure('installed').that_requires('Class[clamav::install]').that_comes_before("File[#{config_file}]") }
          it { is_expected.to contain_package(expected[:package]).that_notifies('Service[clamav-milter]') }
        else
          it { is_expected.to have_package_resource_count(1) }
        end

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('milter', rendered_content(config_file)) }
        end
      end

      context 'with options' do
        let(:params) do
          {
            manage_service: true,
            options: {
              'MilterSocket' => 'inet:7357@localhost',
              'MilterSocketGroup' => :undef,
              'MilterSocketMode' => :undef,
              'ClamdSocket' => ['tcp:scanner1.example.org:3310', 'tcp:scanner2.example.org:3310'],
              'OnInfected' => 'Reject',
              'RejectMsg' => 'Message rejected: infected by %v',
              'AddHeader' => 'Replace',
              'LocalNet' => ['local', '192.0.2.0/24'],
              'LogInfected' => 'Basic',
              'SkipAuthenticated' => '^(alice|bob)$',
            },
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^AddHeader Replace\nClamdSocket tcp:scanner1\.example\.org:3310\nClamdSocket tcp:scanner2\.example\.org:3310\n}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^LocalNet local\nLocalNet 192\.0\.2\.0/24\n}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^MilterSocket inet:7357@localhost\nOnInfected Reject\n}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^RejectMsg Message rejected: infected by %v\nSkipAuthenticated \^\(alice\|bob\)\$\n}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^MilterSocket(Group|Mode)}) }
        it { is_expected.to contain_service('clamav-milter') }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('milter', rendered_content(config_file)) }
        end
      end

      context 'with the options of the Debian package' do
        let(:params) { { default_options: {}, options: debian_options } }

        it { is_expected.to contain_file(config_file).with_content(%r{^LogFileMaxSize 1M\nLogFileUnlock no\nLogInfected Off\nLogRotate yes\n}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('milter', rendered_content(config_file)) }
        end
      end

      context 'with the service stopped' do
        let(:params) { { manage_service: true, service_ensure: 'stopped', service_enable: false, package_ensure: 'latest' } }

        it { is_expected.to contain_service('clamav-milter').with_ensure('stopped').with_enable(false) }
        it { is_expected.to contain_package(expected[:package]).with_ensure('latest') } if expected[:package]
      end

      context 'without service' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('clamav-milter') }
      end
    end
  end
end
