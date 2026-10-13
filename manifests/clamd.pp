# @summary Manages clamd, the ClamAV scanner daemon
#
# Installs clamd, writes its configuration and runs its service. The
# configuration holds `default_options`, the options the packaged service
# needs (socket, user, logging) from the module data, merged with
# `options`. Every other option keeps the ClamAV default, see clamd.conf(5).
#
# The file is checked by clamd before it is replaced, so an option unknown to
# the installed ClamAV fails the Puppet run instead of the service.
#
# @example Listen on TCP as well and raise the scan limits
#   class { 'clamav::clamd':
#     options => {
#       'TCPSocket'   => 3310,
#       'TCPAddr'     => '127.0.0.1',
#       'MaxScanSize' => '400M',
#       'MaxFileSize' => '100M',
#       'ExcludePath' => ['^/proc/', '^/sys/'],
#     },
#   }
#
# @param config_file
#   Path of the configuration file.
# @param service_name
#   Name of the service.
# @param default_options
#   Options the packaged service relies on, from the module data.
# @param package_name
#   Name of the clamd package, undef when the base package ships clamd.
# @param package_ensure
#   Ensure value of the package.
# @param options
#   Options merged over `default_options`. An undef value removes an option.
# @param validate
#   Check the configuration with `clamd --config-file <file> --version`
#   before replacing it.
# @param manage_service
#   Whether to manage the service.
# @param service_ensure
#   Ensure value of the service.
# @param service_enable
#   Whether the service starts at boot.
class clamav::clamd (
  Stdlib::Absolutepath $config_file,
  String[1] $service_name,
  Clamav::Options $default_options,
  Optional[String[1]] $package_name = undef,
  String[1] $package_ensure = 'installed',
  Clamav::Options $options = {},
  Boolean $validate = true,
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
    true    => '/usr/sbin/clamd --config-file=% --version',
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
