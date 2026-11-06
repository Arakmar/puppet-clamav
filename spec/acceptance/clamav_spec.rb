# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'clamav' do
  os_family = ClamavAcceptance.os_family

  it_behaves_like 'an idempotent resource' do
    let(:manifest) do
      <<~PUPPET
        #{ClamavAcceptance.repository_overrides}
        class { 'clamav::clamd': }

        class { 'clamav::freshclam':
          mode        => 'timer',
          on_calendar => '*-*-* 03:30:00',
          timer_entry => { 'RandomizedDelaySec' => 0 },
        }

        class { 'clamav::milter':
          allow_list => ['To:^postmaster@example\\.org$'],
        }

        file { '/var/lib/clamav/acceptance.hdb':
          ensure  => file,
          content => "#{ClamavAcceptance::SIGNATURE}\\n",
          require => Class['clamav'],
          before  => Class['clamav::clamd'],
        }

        #{ClamavAcceptance.database_dropins}
      PUPPET
    end
  end

  [os_family[:clamd_service], os_family[:milter_service]].compact.each do |name|
    describe service(name) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  describe process('clamd') do
    its(:user) { is_expected.to eq ClamavAcceptance.os_family[:clamd_user] }
  end

  describe file(os_family[:clamd_socket]) do
    it { is_expected.to be_socket }
  end

  # clamd answers on the socket of its configuration file
  describe command("printf '#{ClamavAcceptance::SAMPLE.chomp}\\n' > /tmp/acceptance-sample && clamdscan --config-file=#{os_family[:clamd_config]} --no-summary --stream /tmp/acceptance-sample") do
    its(:exit_status) { is_expected.to eq 1 }
    its(:stdout) { is_expected.to match(%r{^/tmp/acceptance-sample: Acceptance\.Test(\.UNOFFICIAL)? FOUND$}) }
  end

  describe file(os_family[:freshclam_config]) do
    its(:content) { is_expected.to match(%r{^DatabaseDirectory /var/lib/clamav$}) }
  end

  describe service('clamav-freshclam') do
    it { is_expected.not_to be_running }
  end

  # be_enabled also looks for the SysV links, which Debian 13 leaves behind
  describe command('systemctl is-enabled clamav-freshclam') do
    its(:stdout) { is_expected.to eq "disabled\n" }
  end

  describe service('clamav-freshclam-once.timer') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  # The drop-in replaces the daily schedule of the packaged timer
  describe command('systemctl show --property=TimersCalendar clamav-freshclam-once.timer') do
    its(:stdout) { is_expected.to include('OnCalendar=*-*-* 03:30:00') }
    its(:stdout) { is_expected.not_to include('00:00:00') }
  end

  describe file(os_family[:milter_allow_list]) do
    its(:content) { is_expected.to eq("# Managed by Puppet\nTo:^postmaster@example\\.org$\n") }
  end

  describe file(os_family[:milter_config]) do
    its(:content) { is_expected.to match(%r{^AllowList #{Regexp.escape(ClamavAcceptance.os_family[:milter_allow_list])}$}) }
  end

  if os_family[:milter_service]
    describe file(os_family[:milter_socket]) do
      it { is_expected.to be_socket }
    end
  end

  if ClamavAcceptance.crb?
    describe command('dnf --quiet repolist --enabled crb') do
      its(:stdout) { is_expected.to match(%r{^crb\s}) }
    end
  end
end
