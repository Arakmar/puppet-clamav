# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::freshclam' do
  # The freshclam.conf of the Debian 13 package
  debian_options = {
    'DatabaseOwner' => 'clamav', 'UpdateLogFile' => '/var/log/clamav/freshclam.log', 'LogVerbose' => false, 'LogSyslog' => false,
    'LogFacility' => 'LOG_LOCAL6', 'LogFileMaxSize' => 0, 'LogRotate' => true, 'LogTime' => true, 'Foreground' => false, 'Debug' => false,
    'MaxAttempts' => 5, 'DatabaseDirectory' => '/var/lib/clamav', 'DNSDatabaseInfo' => 'current.cvd.clamav.net', 'ConnectTimeout' => 30,
    'ReceiveTimeout' => 0, 'TestDatabases' => true, 'ScriptedUpdates' => true, 'CompressLocalDatabase' => false, 'Bytecode' => true,
    'NotifyClamd' => '/etc/clamav/clamd.conf', 'Checks' => 24, 'DatabaseMirror' => ['db.local.clamav.net', 'database.clamav.net']
  }

  context 'validated by ClamAV' do
    it 'rejects an unknown option' do
      expect(expect_valid_for_clamav('freshclam', "DatabaseMirror database.clamav.net\nUnknownOption yes\n", valid: false)).to match(%r{Unknown option UnknownOption})
    end
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      expected = {
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
            .with_validate_cmd('/usr/bin/freshclam --config-file=% --version')
            .that_requires('Class[clamav::install]')
        end

        it { is_expected.to contain_service('clamav-freshclam').with_ensure('running').with_enable(true).that_subscribes_to("File[#{config_file}]") }

        if expected[:package]
          it { is_expected.to contain_package(expected[:package]).with_ensure('installed').that_requires('Class[clamav::install]').that_comes_before("File[#{config_file}]") }
          it { is_expected.to contain_package(expected[:package]).that_notifies('Service[clamav-freshclam]') }
        else
          it { is_expected.to have_package_resource_count(1) }
        end

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(config_file)) }
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

        it { is_expected.to contain_file(config_file).with_content(%r{^Checks 12\nDatabaseCustomURL https://sigs\.example\.org/custom\.ndb\nDatabaseCustomURL https://sigs\.example\.org/custom\.hdb\n}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DatabaseMirror mirror1\.example\.org\nDatabaseMirror mirror2\.example\.org\n}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^HTTPProxyPort 3128\nHTTPProxyServer proxy\.example\.org$}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^DatabaseOwner}).without_content(%r{database\.clamav\.net}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(config_file)) }
        end
      end

      context 'with the options of the Debian package' do
        let(:params) { { default_options: {}, options: debian_options } }

        it { is_expected.to contain_file(config_file).with_content(%r{^LogFileMaxSize 0\nLogRotate yes\n}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('freshclam', rendered_content(config_file)) }
        end
      end

      context 'without validation nor service' do
        let(:params) { { validate: false, manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file(config_file).with_validate_cmd(nil) }
        it { is_expected.not_to contain_service('clamav-freshclam') }
      end

      context 'with the service stopped' do
        let(:params) { { service_ensure: 'stopped', service_enable: false } }

        it { is_expected.to contain_service('clamav-freshclam').with_ensure('stopped').with_enable(false) }
      end
    end
  end
end
