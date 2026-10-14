# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::milter' do
  # The clamav-milter.conf of the Debian 13 package, without
  # TemporaryDirectory which clamav-milter ignores
  let(:debian_options) do
    {
      'MilterSocket' => '/var/run/clamav/clamav-milter.ctl', 'FixStaleSocket' => true, 'User' => 'clamav', 'ReadTimeout' => 120,
      'Foreground' => false, 'PidFile' => '/var/run/clamav/clamav-milter.pid', 'ClamdSocket' => 'unix:/var/run/clamav/clamd.ctl',
      'OnClean' => 'Accept', 'OnInfected' => 'Quarantine', 'OnFail' => 'Defer', 'AddHeader' => 'Replace', 'LogSyslog' => false,
      'LogFacility' => 'LOG_LOCAL6', 'LogVerbose' => false, 'LogInfected' => 'Off', 'LogClean' => 'Off', 'LogRotate' => true,
      'MaxFileSize' => '25M', 'SupportMultipleRecipients' => false, 'LogFile' => '/var/log/clamav/clamav-milter.log', 'LogTime' => true,
      'LogFileUnlock' => false, 'LogFileMaxSize' => '1M', 'MilterSocketGroup' => 'clamav', 'MilterSocketMode' => '666',
    }
  end

  context 'validated by ClamAV', :clamav do
    it 'rejects an unknown option' do
      expect(expect_valid_for_clamav('milter', "MilterSocket /run/milter.sock\nUnknownOption yes\n", valid: false)).to include('Unknown option UnknownOption')
    end
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      # Arch Linux ships the daemons in the base package, and no milter unit
      arch = os_facts[:os]['family'] == 'Archlinux'

      let(:facts) { os_facts }

      let(:expected) do
        {
          'Archlinux' => {
            package: nil,
            service: false,
            config_file: '/etc/clamav/clamav-milter.conf',
            allow_list_file: '/etc/clamav/clamav-milter-allowlist.conf',
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
            allow_list_file: '/etc/clamav/clamav-milter-allowlist.conf',
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
            allow_list_file: '/etc/mail/clamav-milter-allowlist.conf',
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
        }.fetch(facts[:os]['family'])
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('clamav') }

        it do
          is_expected.to contain_file(expected[:config_file])
            .with_ensure('file')
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
            .with_content(expected[:content])
            .with_validate_cmd(nil)
            .that_requires('Class[clamav::install]')
        end

        it { is_expected.not_to contain_file(expected[:allow_list_file]) }

        if arch
          it { is_expected.not_to contain_service('clamav-milter') }
        else
          it { is_expected.to contain_service('clamav-milter').with_ensure('running').with_enable(true).that_subscribes_to("File[#{expected[:config_file]}]") }
        end

        if arch
          it { is_expected.to have_package_resource_count(1) }
        else
          it { is_expected.to contain_package(expected[:package]).with_ensure('installed').that_requires('Class[clamav::install]').that_comes_before("File[#{expected[:config_file]}]") }
          it { is_expected.to contain_package(expected[:package]).that_notifies('Service[clamav-milter]') }
        end

        context 'validated by ClamAV', :clamav do
          it { expect_valid_for_clamav('milter', rendered_content(expected[:config_file])) }
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

        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^AddHeader Replace\nClamdSocket tcp:scanner1\.example\.org:3310\nClamdSocket tcp:scanner2\.example\.org:3310\n}) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^LocalNet local\nLocalNet 192\.0\.2\.0/24\n}) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^MilterSocket inet:7357@localhost\nOnInfected Reject\n}) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^RejectMsg Message rejected: infected by %v\nSkipAuthenticated \^\(alice\|bob\)\$\n}) }
        it { is_expected.to contain_file(expected[:config_file]).without_content(%r{^MilterSocket(Group|Mode)}) }
        it { is_expected.to contain_service('clamav-milter') }

        context 'validated by ClamAV', :clamav do
          it { expect_valid_for_clamav('milter', rendered_content(expected[:config_file])) }
        end
      end

      context 'with the options of the Debian package' do
        let(:params) { { default_options: {}, options: debian_options } }

        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^LogFileMaxSize 1M\nLogFileUnlock no\nLogInfected Off\nLogRotate yes\n}) }

        context 'validated by ClamAV', :clamav do
          it { expect_valid_for_clamav('milter', rendered_content(expected[:config_file])) }
        end
      end

      context 'with an allow list' do
        let(:params) { { manage_service: true, allow_list: ['From:^postmaster@example\\.org$', 'To:^abuse@', '^noscan@example\\.org$'] } }

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file(expected[:allow_list_file])
            .with_ensure('file')
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
            .with_content("# Managed by Puppet\nFrom:^postmaster@example\\.org$\nTo:^abuse@\n^noscan@example\\.org$\n")
            .that_requires('Class[clamav::install]')
            .that_notifies('Service[clamav-milter]')
        end

        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^AllowList #{expected[:allow_list_file]}\nClamdSocket }) }

        it { is_expected.to contain_package(expected[:package]).that_comes_before("File[#{expected[:allow_list_file]}]") } unless arch

        context 'validated by ClamAV', :clamav do
          it { expect_valid_for_clamav('milter', rendered_content(expected[:config_file])) }
        end
      end

      context 'with an allow list set in the options' do
        let(:params) { { allow_list: ['To:^abuse@'], options: { 'AllowList' => '/etc/allowed' } } }

        it { is_expected.to contain_file(expected[:allow_list_file]) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^AllowList /etc/allowed$}) }
      end

      context 'with the expected[:service] stopped' do
        let(:params) { { manage_service: true, service_ensure: 'stopped', service_enable: false, package_ensure: 'latest' } }

        it { is_expected.to contain_service('clamav-milter').with_ensure('stopped').with_enable(false) }

        it { is_expected.to contain_package(expected[:package]).with_ensure('latest') } unless arch
      end

      context 'without expected[:service]' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('clamav-milter') }
      end
    end
  end
end
