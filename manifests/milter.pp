# @summary Manages clamav-milter, which scans the mail of an MTA with clamd
#
# Installs clamav-milter, writes its configuration and runs its service. The
# configuration holds `default_options`, the sockets and user the packaged
# service relies on from the module data, merged with `options`. Every other
# option keeps the ClamAV default, see clamav-milter.conf(5). Unlike clamd
# and freshclam, clamav-milter cannot check a configuration file without
# starting, so the file is not validated.
#
# The milter connects to the clamd sockets of `ClamdSocket`, by default the
# local socket of clamav::clamd. The MTA must be able to reach
# `MilterSocket`: on the RedHat family, the postfix user has to join the
# clamilt group.
#
# @example Reject infected mail
#   class { 'clamav::milter':
#     options => {
#       'OnInfected' => 'Reject',
#       'RejectMsg'  => 'Message rejected: infected by %v',
#       'AddHeader'  => 'Replace',
#       'LocalNet'   => ['local', '192.0.2.0/24'],
#     },
#   }
#
# @example Do not scan the mail of some addresses
#   class { 'clamav::milter':
#     allow_list => ['From:^postmaster@example\.org$', 'To:^abuse@'],
#   }
#
# @param config_file
#   Path of the configuration file.
# @param default_options
#   Options the packaged service relies on, from the module data.
# @param allow_list_file
#   File holding `allow_list`.
# @param package_name
#   Name of the clamav-milter package, undef when the base package ships the
#   milter.
# @param package_ensure
#   Ensure value of the package.
# @param options
#   Options merged over `default_options`. An undef value removes an option.
# @param allow_list
#   Senders and recipients whose mail is not scanned, as basic POSIX regular
#   expressions, prefixed with `From:` for a sender or `To:` (the default)
#   for a recipient. When not empty they are written to `allow_list_file`,
#   which the `AllowList` option is set to.
# @param service_name
#   Name of the service.
# @param manage_service
#   Whether to manage the service. Arch Linux ships no unit for the milter.
# @param service_ensure
#   Ensure value of the service.
# @param service_enable
#   Whether the service starts at boot.
class clamav::milter (
  Stdlib::Absolutepath $config_file,
  Clamav::Options $default_options,
  Stdlib::Absolutepath $allow_list_file,
  Optional[String[1]] $package_name = undef,
  String[1] $package_ensure = 'installed',
  Clamav::Options $options = {},
  Array[Pattern[/\A[^\r\n]+\z/]] $allow_list = [],
  String[1] $service_name = 'clamav-milter',
  Boolean $manage_service = true,
  Stdlib::Ensure::Service $service_ensure = 'running',
  Boolean $service_enable = true,
) {
  include clamav

  if $package_name {
    package { $package_name:
      ensure  => $package_ensure,
      require => Class['clamav::install'],
      before  => File[$config_file],
    }
  }

  if $allow_list.empty {
    $allow_list_options = {}
  } else {
    file { $allow_list_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "${(['# Managed by Puppet'] + $allow_list).join("\n")}\n",
      require => Class['clamav::install'],
    }

    if $package_name {
      Package[$package_name] -> File[$allow_list_file]
    }

    $allow_list_options = { 'AllowList' => $allow_list_file }
  }

  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => clamav::to_config($default_options + $allow_list_options + $options),
    require => Class['clamav::install'],
  }

  if $manage_service {
    service { $service_name:
      ensure    => $service_ensure,
      enable    => $service_enable,
      subscribe => File[$config_file],
    }

    unless $allow_list.empty {
      File[$allow_list_file] ~> Service[$service_name]
    }

    if $package_name {
      Package[$package_name] ~> Service[$service_name]
    }
  }
}
