# frozen_string_literal: true

require 'digest'

# What the packages of each OS family ship and the module data points to:
# units, configuration files, sockets and users.
module ClamavAcceptance
  OS_FAMILIES = {
    'Archlinux' => {
      clamd_service: 'clamav-daemon',
      clamd_config: '/etc/clamav/clamd.conf',
      clamd_socket: '/run/clamav/clamd.ctl',
      clamd_user: 'clamav',
      freshclam_config: '/etc/clamav/freshclam.conf',
      milter_config: '/etc/clamav/clamav-milter.conf',
      milter_allow_list: '/etc/clamav/clamav-milter-allowlist.conf',
      # No unit is shipped for the milter
      milter_service: nil,
      # Units that wait for the databases of freshclam
      database_units: %w[clamav-daemon.service clamav-daemon.socket],
    },
    'Debian' => {
      clamd_service: 'clamav-daemon',
      clamd_config: '/etc/clamav/clamd.conf',
      clamd_socket: '/run/clamav/clamd.ctl',
      clamd_user: 'clamav',
      freshclam_config: '/etc/clamav/freshclam.conf',
      milter_config: '/etc/clamav/clamav-milter.conf',
      milter_allow_list: '/etc/clamav/clamav-milter-allowlist.conf',
      milter_service: 'clamav-milter',
      milter_socket: '/run/clamav/clamav-milter.ctl',
      database_units: %w[clamav-daemon.service clamav-daemon.socket],
    },
    'RedHat' => {
      clamd_service: 'clamd@scan',
      clamd_config: '/etc/clamd.d/scan.conf',
      clamd_socket: '/run/clamd.scan/clamd.sock',
      clamd_user: 'clamscan',
      freshclam_config: '/etc/freshclam.conf',
      milter_config: '/etc/mail/clamav-milter.conf',
      milter_allow_list: '/etc/mail/clamav-milter-allowlist.conf',
      milter_service: 'clamav-milter',
      milter_socket: '/run/clamav-milter/clamav-milter.socket',
      database_units: [],
    },
  }.freeze

  # freshclam cannot download the databases in the containers: clamd loads
  # the signature of this test file instead, and the units waiting for the
  # databases start without them.
  SAMPLE = "clamav acceptance test\n"
  SIGNATURE = "#{Digest::MD5.hexdigest(SAMPLE)}:#{SAMPLE.bytesize}:Acceptance.Test"

  # The expectations for the OS family of the host. The hosts are set up when
  # the specs are loaded, so this can choose the examples to define.
  def self.os_family
    @os_family ||= OS_FAMILIES.fetch(fact('os.family'))
  end

  # puppet/epel 6.1.0 points EPEL at epel-10. on CentOS Stream 10, which has
  # no minor release: the repository of its epel-release package instead, as
  # the README advises.
  def self.repository_overrides
    return '' unless fact('os.name') == 'CentOS' && fact('os.release.major') == '10'

    <<~PUPPET
      class { 'epel':
        epel_metalink => 'https://mirrors.fedoraproject.org/metalink?repo=epel-10s&arch=$basearch',
      }
    PUPPET
  end

  # Drop-ins starting the units that wait for the databases without them
  def self.database_dropins
    os_family[:database_units].map do |unit|
      <<~PUPPET
        systemd::dropin_file { '#{unit}-acceptance.conf':
          unit     => '#{unit}',
          filename => 'acceptance.conf',
          content  => "[Unit]\\nConditionPathExistsGlob=\\n",
          before   => Class['clamav::clamd'],
        }
      PUPPET
    end.join("\n")
  end

  # Whether the module enables CRB along with EPEL: on EL 9 but RHEL
  def self.crb?
    fact('os.family') == 'RedHat' && fact('os.name') != 'RedHat' && fact('os.release.major') == '9'
  end
end
