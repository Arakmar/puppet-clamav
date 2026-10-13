# frozen_string_literal: true

require 'spec_helper'

describe 'clamav::clamd' do
  # The clamd.conf of the Debian 13 package, with the options its
  # configuration script writes
  debian_options = {
    'LocalSocket' => '/var/run/clamav/clamd.ctl', 'FixStaleSocket' => true, 'LocalSocketGroup' => 'clamav', 'LocalSocketMode' => '666',
    'User' => 'clamav', 'ScanMail' => true, 'ScanArchive' => true, 'ArchiveBlockEncrypted' => false, 'MaxDirectoryRecursion' => 15,
    'FollowDirectorySymlinks' => false, 'FollowFileSymlinks' => false, 'ReadTimeout' => 180, 'MaxThreads' => 12, 'MaxConnectionQueueLength' => 15,
    'LogSyslog' => false, 'LogRotate' => true, 'LogFacility' => 'LOG_LOCAL6', 'LogClean' => false, 'LogVerbose' => false, 'PreludeEnable' => false,
    'PreludeAnalyzerName' => 'ClamAV', 'DatabaseDirectory' => '/var/lib/clamav', 'OfficialDatabaseOnly' => false, 'SelfCheck' => 3600,
    'Foreground' => false, 'Debug' => false, 'ScanPE' => true, 'MaxEmbeddedPE' => '10M', 'ScanOLE2' => true, 'ScanPDF' => true, 'ScanHTML' => true,
    'MaxHTMLNormalize' => '10M', 'MaxHTMLNoTags' => '2M', 'MaxScriptNormalize' => '5M', 'MaxZipTypeRcg' => '1M', 'ScanSWF' => true,
    'ExitOnOOM' => false, 'LeaveTemporaryFiles' => false, 'AlgorithmicDetection' => true, 'ScanELF' => true, 'IdleTimeout' => 30,
    'CrossFilesystems' => true, 'PhishingSignatures' => true, 'PhishingScanURLs' => true, 'PhishingAlwaysBlockSSLMismatch' => false,
    'PhishingAlwaysBlockCloak' => false, 'PartitionIntersection' => false, 'DetectPUA' => false, 'ScanPartialMessages' => false,
    'HeuristicScanPrecedence' => false, 'StructuredDataDetection' => false, 'CommandReadTimeout' => 30, 'SendBufTimeout' => 200, 'MaxQueue' => 100,
    'ExtendedDetectionInfo' => true, 'OLE2BlockMacros' => false, 'AllowAllMatchScan' => true, 'ForceToDisk' => false, 'DisableCertCheck' => false,
    'DisableCache' => false, 'MaxScanTime' => 120_000, 'MaxScanSize' => '100M', 'MaxFileSize' => '25M', 'MaxRecursion' => 16, 'MaxFiles' => 10_000,
    'MaxPartitions' => 50, 'MaxIconsPE' => 100, 'PCREMatchLimit' => 10_000, 'PCRERecMatchLimit' => 5000, 'PCREMaxFileSize' => '25M',
    'ScanXMLDOCS' => true, 'ScanHWP3' => true, 'MaxRecHWP3' => 16, 'StreamMaxLength' => '25M', 'LogFile' => '/var/log/clamav/clamav.log',
    'LogTime' => true, 'LogFileUnlock' => false, 'LogFileMaxSize' => 0, 'Bytecode' => true, 'BytecodeSecurity' => 'TrustSigned',
    'BytecodeTimeout' => 60_000, 'OnAccessMaxFileSize' => '5M'
  }

  context 'validated by ClamAV' do
    it 'rejects an unknown option' do
      expect(expect_valid_for_clamav('clamd', "LocalSocket /run/clamd.sock\nUnknownOption yes\n", valid: false)).to match(%r{Unknown option UnknownOption})
    end

    it 'rejects an invalid value' do
      expect(expect_valid_for_clamav('clamd', "LocalSocket /run/clamd.sock\nMaxThreads many\n", valid: false)).to match(%r{MaxThreads})
    end
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      expected = {
        'Archlinux' => {
          package: nil,
          config_file: '/etc/clamav/clamd.conf',
          service: 'clamav-daemon',
          content: <<~CONF,
            # Managed by Puppet
            DatabaseDirectory /var/lib/clamav
            LocalSocket /run/clamav/clamd.ctl
            LogFile /var/log/clamav/clamd.log
            LogTime yes
            PidFile /run/clamav/clamd.pid
            User clamav
          CONF
        },
        'Debian' => {
          package: 'clamav-daemon',
          config_file: '/etc/clamav/clamd.conf',
          service: 'clamav-daemon',
          content: <<~CONF,
            # Managed by Puppet
            DatabaseDirectory /var/lib/clamav
            FixStaleSocket yes
            LocalSocket /run/clamav/clamd.ctl
            LocalSocketGroup clamav
            LocalSocketMode 666
            LogFile /var/log/clamav/clamav.log
            LogTime yes
            User clamav
          CONF
        },
        'RedHat' => {
          package: 'clamd',
          config_file: '/etc/clamd.d/scan.conf',
          service: 'clamd@scan',
          content: <<~CONF,
            # Managed by Puppet
            DatabaseDirectory /var/lib/clamav
            FixStaleSocket yes
            LocalSocket /run/clamd.scan/clamd.sock
            LocalSocketGroup virusgroup
            LocalSocketMode 660
            LogSyslog yes
            PidFile /run/clamd.scan/clamd.pid
            User clamscan
          CONF
        },
      }.fetch(os_facts[:os]['family'])
      config_file = expected[:config_file]
      service = expected[:service]

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
            .with_validate_cmd('/usr/sbin/clamd --config-file=% --version')
            .that_requires('Class[clamav::install]')
        end

        it { is_expected.to contain_service(service).with_ensure('running').with_enable(true).that_subscribes_to("File[#{config_file}]") }

        if expected[:package]
          it { is_expected.to contain_package(expected[:package]).with_ensure('installed').that_requires('Class[clamav::install]').that_comes_before("File[#{config_file}]") }
          it { is_expected.to contain_package(expected[:package]).that_notifies("Service[#{service}]") }
        else
          it { is_expected.to have_package_resource_count(1) }
        end

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('clamd', rendered_content(config_file)) }
        end
      end

      context 'with options' do
        let(:params) do
          {
            options: {
              'TCPSocket' => 3310,
              'TCPAddr' => ['127.0.0.1', '::1'],
              'MaxThreads' => 4,
              'MaxScanSize' => '400M',
              'ExcludePath' => ['^/proc/', '^/sys/'],
              'HeuristicAlerts' => true,
              'AlertEncrypted' => false,
              'LogTime' => :undef,
              'User' => 'scanner',
            },
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^AlertEncrypted no$}).with_content(%r{^HeuristicAlerts yes$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^ExcludePath \^/proc/\nExcludePath \^/sys/$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^MaxScanSize 400M\nMaxThreads 4$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^TCPAddr 127\.0\.0\.1\nTCPAddr ::1\nTCPSocket 3310\nUser scanner\n\z}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^LogTime}).without_content(%r{^User clam}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('clamd', rendered_content(config_file)) }
        end
      end

      context 'with the options of the Debian package' do
        let(:params) { { default_options: {}, options: debian_options } }

        it { is_expected.to contain_file(config_file).with_content(%r{\A# Managed by Puppet\nAlgorithmicDetection yes\nAllowAllMatchScan yes\n}) }

        context 'validated by ClamAV' do
          it { expect_valid_for_clamav('clamd', rendered_content(config_file)) }
        end
      end

      context 'with a value spanning several lines' do
        let(:params) { { options: { 'ExcludePath' => "^/proc/\nUser root" } } }

        it { is_expected.to compile.and_raise_error(%r{options}) }
      end

      context 'without validation nor service' do
        let(:params) { { validate: false, manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file(config_file).with_validate_cmd(nil) }
        it { is_expected.not_to contain_service(service) }
      end

      context 'with the service stopped' do
        let(:params) { { service_ensure: 'stopped', service_enable: false, package_ensure: 'latest' } }

        it { is_expected.to contain_service(service).with_ensure('stopped').with_enable(false) }
        it { is_expected.to contain_package(expected[:package]).with_ensure('latest') } if expected[:package]
      end

      context 'with another package, file and service' do
        let(:params) { { package_name: 'clamd-custom', config_file: '/etc/clamd.conf', service_name: 'clamd' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/clamd.conf').with_content(expected[:content]) }
        it { is_expected.to contain_package('clamd-custom').that_comes_before('File[/etc/clamd.conf]') }
        it { is_expected.to contain_service('clamd').that_subscribes_to(['File[/etc/clamd.conf]', 'Package[clamd-custom]']) }
      end
    end
  end
end
