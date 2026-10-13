# @summary Manages freshclam, the ClamAV database updater
#
# Installs freshclam, writes its configuration and runs its daemon. The
# configuration holds `default_options`, the options the packaged service
# needs from the module data, merged with `options`. Every other option
# keeps the ClamAV default, see freshclam.conf(5).
#
# The file is checked by freshclam before it is replaced.
#
# @example Download through a proxy and tell clamd about new databases
#   class { 'clamav::freshclam':
#     options => {
#       'HTTPProxyServer' => 'proxy.example.org',
#       'HTTPProxyPort'   => 3128,
#       'NotifyClamd'     => '/etc/clamav/clamd.conf',
#     },
#   }
#
# @param config_file
#   Path of the configuration file.
# @param default_options
#   Options the packaged service relies on, from the module data.
# @param package_name
#   Name of the freshclam package, undef when the base package ships
#   freshclam.
# @param package_ensure
#   Ensure value of the package.
# @param options
#   Options merged over `default_options`. An undef value removes an option.
# @param validate
#   Check the configuration with `freshclam --config-file <file> --version`
#   before replacing it.
# @param service_name
#   Name of the freshclam daemon service.
# @param manage_service
#   Whether to manage the service.
# @param service_ensure
#   Ensure value of the service.
# @param service_enable
#   Whether the service starts at boot.
class clamav::freshclam (
  Stdlib::Absolutepath $config_file,
  Clamav::Options $default_options,
  Optional[String[1]] $package_name = undef,
  String[1] $package_ensure = 'installed',
  Clamav::Options $options = {},
  Boolean $validate = true,
  String[1] $service_name = 'clamav-freshclam',
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

  $validate_cmd = $validate ? {
    true    => '/usr/bin/freshclam --config-file=% --version',
    default => undef,
  }

  file { $config_file:
    ensure       => file,
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    content      => clamav::to_config($default_options + $options),
    validate_cmd => $validate_cmd,
    require      => Class['clamav::install'],
  }

  if $manage_service {
    service { $service_name:
      ensure    => $service_ensure,
      enable    => $service_enable,
      subscribe => File[$config_file],
    }

    if $package_name {
      Package[$package_name] ~> Service[$service_name]
    }
  }
}
