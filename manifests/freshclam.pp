# @summary Manages freshclam, the ClamAV database updater
#
# Installs freshclam, writes its configuration and runs it. The
# configuration holds `default_options`, the options the packaged service
# needs from the module data, merged with `options`. Every other option
# keeps the ClamAV default, see freshclam.conf(5).
#
# The file is checked by freshclam before it is replaced.
#
# freshclam runs either as a daemon checking for updates `Checks` times a
# day (12 by default), or once a day from the `clamav-freshclam-once.timer`
# systemd timer shipped by the packages, whose schedule can be changed. The
# unit of the other mode is stopped and disabled.
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
# @example Update the databases every night at 3:30 from the systemd timer
#   class { 'clamav::freshclam':
#     mode        => 'timer',
#     on_calendar => '*-*-* 03:30:00',
#     timer_entry => { 'RandomizedDelaySec' => 0, 'AccuracySec' => '1min' },
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
# @param mode
#   How freshclam runs: `daemon` (the `service_name` service) or `timer`
#   (the `timer_name` timer).
# @param service_name
#   Name of the freshclam daemon service.
# @param timer_name
#   Name of the systemd timer running freshclam once.
# @param on_calendar
#   Schedule of the timer, as one or more systemd `OnCalendar` expressions
#   replacing the packaged `daily`. The packaged timer also sets
#   `RandomizedDelaySec=1h` and `AccuracySec=1h`, see `timer_entry`.
# @param timer_entry
#   Settings of the `[Timer]` section of the timer, merged after
#   `on_calendar` in a drop-in.
# @param manage_service
#   Whether to manage the daemon service, the timer and its drop-in.
# @param service_ensure
#   Ensure value of the unit of `mode`.
# @param service_enable
#   Whether the unit of `mode` starts at boot.
class clamav::freshclam (
  Stdlib::Absolutepath $config_file,
  Clamav::Options $default_options,
  Optional[String[1]] $package_name = undef,
  String[1] $package_ensure = 'installed',
  Clamav::Options $options = {},
  Boolean $validate = true,
  Enum['daemon', 'timer'] $mode = 'daemon',
  String[1] $service_name = 'clamav-freshclam',
  Pattern[/\A[^\/]+\.timer\z/] $timer_name = 'clamav-freshclam-once.timer',
  Optional[Variant[String[1], Array[String[1], 1]]] $on_calendar = undef,
  Systemd::Unit::Timer $timer_entry = {},
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
    # The unit of the other mode is stopped and disabled
    [$daemon_ensure, $daemon_enable, $timer_ensure, $timer_enable] = $mode ? {
      'daemon' => [$service_ensure, $service_enable, 'stopped', false],
      default  => ['stopped', false, $service_ensure, $service_enable],
    }

    service { $service_name:
      ensure    => $daemon_ensure,
      enable    => $daemon_enable,
      subscribe => File[$config_file],
    }

    service { $timer_name:
      ensure  => $timer_ensure,
      enable  => $timer_enable,
      require => Class['clamav::install'],
    }

    # An empty OnCalendar first drops the schedule of the packaged timer
    $calendar = $on_calendar ? {
      undef   => {},
      default => { 'OnCalendar' => [''] + Array($on_calendar, true) },
    }
    $dropin = $calendar + $timer_entry
    $dropin_ensure = ($mode == 'timer' and !$dropin.empty) ? {
      true    => 'present',
      default => 'absent',
    }

    systemd::manage_dropin { "${timer_name}-puppet.conf":
      ensure         => $dropin_ensure,
      unit           => $timer_name,
      filename       => 'puppet.conf',
      timer_entry    => $dropin,
      notify_service => true,
    }

    if $package_name {
      Package[$package_name] ~> Service[$service_name, $timer_name]
    }
  }
}
