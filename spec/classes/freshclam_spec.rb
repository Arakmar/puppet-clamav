# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::freshclam' do
  # The freshclam.conf of the Debian 13 package
  let(:debian_options) do
    {
      'DatabaseOwner' => 'clamav', 'UpdateLogFile' => '/var/log/clamav/freshclam.log', 'LogVerbose' => false, 'LogSyslog' => false,
      'LogFacility' => 'LOG_LOCAL6', 'LogFileMaxSize' => 0, 'LogRotate' => true, 'LogTime' => true, 'Foreground' => false, 'Debug' => false,
      'MaxAttempts' => 5, 'DatabaseDirectory' => '/var/lib/clamav', 'DNSDatabaseInfo' => 'current.cvd.clamav.net', 'ConnectTimeout' => 30,
      'ReceiveTimeout' => 0, 'TestDatabases' => true, 'ScriptedUpdates' => true, 'CompressLocalDatabase' => false, 'Bytecode' => true,
      'NotifyClamd' => '/etc/clamav/clamd.conf', 'Checks' => 24, 'DatabaseMirror' => ['db.local.clamav.net', 'database.clamav.net'],
    }
  end

  context 'validated by ClamAV' do
    it 'rejects an unknown option' do
      expect(expect_valid_for_clamav('freshclam', "DatabaseMirror database.clamav.net\nUnknownOption yes\n", valid: false)).to include('Unknown option UnknownOption')
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
            config_file: '/etc/clamav/freshclam.conf',
            content: <<~CONF,
              # Managed by Puppet
              DatabaseDirectory /var/lib/clamav
              DatabaseMirror database.clamav.net
              DatabaseOwner clamav
              LogTime yes
              PidFile /run/clamav/freshclam.pid
              UpdateLogFile /var/log/clamav/freshclam.log
            CONF
          },
          'Debian' => {
            package: 'clamav-freshclam',
            config_file: '/etc/clamav/freshclam.conf',
            content: <<~CONF,
              # Managed by Puppet
              DatabaseDirectory /var/lib/clamav
              DatabaseMirror database.clamav.net
              DatabaseOwner clamav
              LogTime yes
              UpdateLogFile /var/log/clamav/freshclam.log
            CONF
          },
          'RedHat' => {
            package: 'clamav-freshclam',
            config_file: '/etc/freshclam.conf',
            content: <<~CONF,
              # Managed by Puppet
              DatabaseDirectory /var/lib/clamav
              DatabaseMirror database.clamav.net
              DatabaseOwner clamupdate
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
            .with_validate_cmd('/usr/bin/freshclam --config-file=% --version')
            .that_requires('Class[clamav::install]')
        end

        it { is_expected.to contain_service('clamav-freshclam').with_ensure('running').with_enable(true).that_subscribes_to("File[#{expected[:config_file]}]") }
        it { is_expected.to contain_service('clamav-freshclam-once.timer').with_ensure('stopped').with_enable(false).that_requires('Class[clamav::install]') }
        it { is_expected.to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf').with_ensure('absent') }
        it { is_expected.to contain_file('/etc/systemd/system/clamav-freshclam-once.timer.d/puppet.conf').with_ensure('absent') }

        if arch
          it { is_expected.to have_package_resource_count(1) }
        else
          it { is_expected.to contain_package(expected[:package]).with_ensure('installed').that_requires('Class[clamav::install]').that_comes_before("File[#{expected[:config_file]}]") }
          it { is_expected.to contain_package(expected[:package]).that_notifies(['Service[clamav-freshclam]', 'Service[clamav-freshclam-once.timer]']) }
        end

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(expected[:config_file])) }
        end
      end

      context 'with options' do
        let(:params) do
          {
            options: {
              'DatabaseMirror' => ['mirror1.example.org', 'mirror2.example.org'],
              'HTTPProxyServer' => 'proxy.example.org',
              'HTTPProxyPort' => 3128,
              'NotifyClamd' => '/etc/clamav/clamd.conf',
              'Checks' => 12,
              'DatabaseCustomURL' => ['https://sigs.example.org/custom.ndb', 'https://sigs.example.org/custom.hdb'],
              'OnUpdateExecute' => '/usr/local/bin/clamav-updated',
              'DatabaseOwner' => :undef,
            },
          }
        end

        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^Checks 12\nDatabaseCustomURL https://sigs\.example\.org/custom\.ndb\nDatabaseCustomURL https://sigs\.example\.org/custom\.hdb\n}) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^DatabaseMirror mirror1\.example\.org\nDatabaseMirror mirror2\.example\.org\n}) }
        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^HTTPProxyPort 3128\nHTTPProxyServer proxy\.example\.org$}) }
        it { is_expected.to contain_file(expected[:config_file]).without_content(%r{^DatabaseOwner}).without_content(%r{database\.clamav\.net}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(expected[:config_file])) }
        end
      end

      context 'with the options of the Debian package' do
        let(:params) { { default_options: {}, options: debian_options } }

        it { is_expected.to contain_file(expected[:config_file]).with_content(%r{^LogFileMaxSize 0\nLogRotate yes\n}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(expected[:config_file])) }
        end
      end

      context 'without validation nor expected[:service]' do
        let(:params) { { validate: false, manage_service: false, mode: 'timer', on_calendar: 'hourly' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file(expected[:config_file]).with_validate_cmd(nil) }
        it { is_expected.not_to contain_service('clamav-freshclam') }
        it { is_expected.not_to contain_service('clamav-freshclam-once.timer') }
        it { is_expected.not_to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf') }
      end

      context 'with the expected[:service] stopped' do
        let(:params) { { service_ensure: 'stopped', service_enable: false } }

        it { is_expected.to contain_service('clamav-freshclam').with_ensure('stopped').with_enable(false) }
        it { is_expected.to contain_service('clamav-freshclam-once.timer').with_ensure('stopped').with_enable(false) }
      end

      context 'with the packaged timer' do
        let(:params) { { mode: 'timer' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_service('clamav-freshclam').with_ensure('stopped').with_enable(false) }
        it { is_expected.to contain_service('clamav-freshclam-once.timer').with_ensure('running').with_enable(true) }
        it { is_expected.to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf').with_ensure('absent') }
      end

      context 'with the timer on a schedule' do
        let(:params) do
          {
            mode: 'timer',
            on_calendar: '*-*-* 03:30:00',
            timer_entry: { 'RandomizedDelaySec' => 0, 'AccuracySec' => '1min' },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf')
            .with_ensure('present')
            .with_unit('clamav-freshclam-once.timer')
            .with_filename('puppet.conf')
            .with_timer_entry('OnCalendar' => ['', '*-*-* 03:30:00'], 'RandomizedDelaySec' => 0, 'AccuracySec' => '1min')
        end

        it do
          is_expected.to contain_file('/etc/systemd/system/clamav-freshclam-once.timer.d/puppet.conf')
            .with_content(%r{^\[Timer\]\nOnCalendar=\nOnCalendar=\*-\*-\* 03:30:00\nRandomizedDelaySec=0\nAccuracySec=1min\n})
            .that_notifies('Service[clamav-freshclam-once.timer]')
        end
      end

      context 'with the timer on several schedules' do
        let(:params) { { mode: 'timer', on_calendar: ['*-*-* 03:30:00', '*-*-* 15:30:00'] } }

        it { is_expected.to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf').with_timer_entry('OnCalendar' => ['', '*-*-* 03:30:00', '*-*-* 15:30:00']) }
      end

      context 'with a schedule in daemon mode' do
        let(:params) { { on_calendar: 'hourly' } }

        it { is_expected.to contain_systemd__manage_dropin('clamav-freshclam-once.timer-puppet.conf').with_ensure('absent') }
      end
    end
  end
end
