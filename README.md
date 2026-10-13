# clamav

[![CI](https://github.com/Arakmar/puppet-clamav/actions/workflows/ci.yml/badge.svg)](https://github.com/Arakmar/puppet-clamav/actions/workflows/ci.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/arakmar/clamav.svg)](https://forge.puppet.com/modules/arakmar/clamav)

## Table of contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage](#usage)
    * [Options and defaults](#options-and-defaults)
    * [Scanner daemon](#scanner-daemon)
    * [Database updates](#database-updates)
    * [Milter](#milter)
    * [User and group](#user-and-group)
    * [Hiera](#hiera)
1. [Upgrading from edestecd-clamav 2.x](#upgrading-from-edestecd-clamav-2x)
1. [Limitations](#limitations)
1. [Development](#development)

## Description

This module installs [ClamAV](https://www.clamav.net/) and manages its
daemons with the packages of each distribution:

* class `clamav` installs the base package (command line scanner and
  libraries), from EPEL on the RedHat family, and can manage the ClamAV
  user;
* `clamav::clamd` manages clamd, the scanner daemon used by clamdscan, MTA
  filters and on-access scanning;
* `clamav::freshclam` manages freshclam, which updates the signature
  databases, as a daemon or from a systemd timer;
* `clamav::milter` manages clamav-milter, which scans the mail of a
  Postfix or Sendmail server with clamd.

Each class writes its configuration file from a hash of ClamAV options and
the daemons check theirs before it is replaced.

## Setup

### Requirements

* Puppet 8 or OpenVox 8.
* [puppetlabs/stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib)
  9.x or 10.x, [puppet/systemd](https://forge.puppet.com/modules/puppet/systemd)
  8.2 or later and, on the RedHat family,
  [puppet/epel](https://forge.puppet.com/modules/puppet/epel) 5.x or 6.x.
* systemd. The packaged releases of ClamAV are:

  | Distribution          | ClamAV | Notes                         |
  |-----------------------|--------|-------------------------------|
  | EL 8 to 10 (EPEL)     | 1.4.6  |                               |
  | Debian 12 and 13      | 1.4.3  |                               |
  | Ubuntu 22.04 and 24.04| 1.5.4  |                               |
  | Arch Linux            | 1.5.4  | no unit for clamav-milter     |

The module is unit tested on EL 8 to 10 (RHEL, CentOS Stream, Rocky,
AlmaLinux), Debian 12 and 13, Ubuntu 22.04 and 24.04 and Arch Linux, and
its configuration files are checked by ClamAV 1.4 and 1.5.

### Beginning with clamav

The command line scanner only:

```puppet
include clamav
```

The scanner daemon with its database updates:

```puppet
include clamav::clamd
include clamav::freshclam
```

## Usage

### Options and defaults

Each class takes the options of its configuration file in `options`, named
as in clamd.conf(5), freshclam.conf(5) and clamav-milter.conf(5):

* booleans are written `yes` and `no`;
* an array repeats the option, for `DatabaseMirror`, `ExcludePath`,
  `TCPAddr`, `LocalNet`, `ClamdSocket` and the other options ClamAV accepts
  several times;
* options are written in alphabetical order.

`options` is merged over `default_options`, which the module data sets to
what the packaged services rely on: sockets, users, log and pid files,
database directory and mirror. Every other option keeps the ClamAV default.
An undef value (`~` in Hiera) removes a default:

```puppet
class { 'clamav::clamd':
  options => {
    'LogFile'   => undef,
    'LogSyslog' => true,
  },
}
```

clamd and freshclam check their file with `--config-file=<file> --version`
before it replaces the previous one, so an option unknown to the installed
ClamAV fails the Puppet run and the running daemon keeps its configuration
(`validate => false` to skip the check). clamav-milter cannot check a file.

### Scanner daemon

```puppet
class { 'clamav::clamd':
  options => {
    'TCPSocket'   => 3310,
    'TCPAddr'     => ['127.0.0.1', '::1'],
    'MaxThreads'  => 4,
    'MaxScanSize' => '400M',
    'MaxFileSize' => '100M',
    'ExcludePath' => ['^/proc/', '^/sys/'],
  },
}
```

The local socket is `/run/clamav/clamd.ctl` on Debian, Ubuntu and Arch
Linux, and `/run/clamd.scan/clamd.sock` on the RedHat family, where clamd
runs as the `clamd@scan` instance with `/etc/clamd.d/scan.conf`.

### Database updates

By default freshclam runs as a daemon, checking for updates `Checks` times a
day (12 by default). Every distribution also ships the
`clamav-freshclam-once.timer` systemd timer, running freshclam once a day
with a random delay of up to an hour. `mode => 'timer'` switches to it and
stops the daemon; `on_calendar` and `timer_entry` change its schedule in a
drop-in:

```puppet
class { 'clamav::freshclam':
  mode        => 'timer',
  on_calendar => '*-*-* 03:30:00',
  timer_entry => { 'RandomizedDelaySec' => 0, 'AccuracySec' => '1min' },
  options     => {
    'DatabaseMirror'  => ['mirror.example.org', 'database.clamav.net'],
    'HTTPProxyServer' => 'proxy.example.org',
    'HTTPProxyPort'   => 3128,
    'NotifyClamd'     => '/etc/clamav/clamd.conf',
  },
}
```

`NotifyClamd` makes freshclam tell clamd to reload the new databases;
clamd also checks for them every `SelfCheck` seconds (600 by default).

### Milter

```puppet
include clamav::clamd

class { 'clamav::milter':
  options    => {
    'OnInfected'  => 'Reject',
    'RejectMsg'   => 'Message rejected: infected by %v',
    'AddHeader'   => 'Replace',
    'LogInfected' => 'Basic',
    'LocalNet'    => ['local', '192.0.2.0/24'],
  },
  allow_list => ['From:^postmaster@example\.org$', 'To:^abuse@'],
}
```

The milter connects to the local clamd socket by default (`ClamdSocket`,
which can list several local or remote clamd). `allow_list` writes the
addresses whose mail is not scanned to a file the `AllowList` option points
to.

The MTA connects to `MilterSocket`:

| Distribution     | `MilterSocket`                                    | Access                                         |
|------------------|---------------------------------------------------|------------------------------------------------|
| Debian, Ubuntu   | `/run/clamav/clamav-milter.ctl`                   | mode 666                                       |
| RedHat family    | `/run/clamav-milter/clamav-milter.socket`         | add the MTA user (postfix) to the clamilt group |
| Arch Linux       | `/run/clamav/clamav-milter.sock`                  | mode 660, group clamav                         |

For Postfix, add the socket to `smtpd_milters`, for example
`unix:/run/clamav/clamav-milter.ctl`. A chrooted smtpd, the Debian default,
only sees the sockets below its chroot (`/var/spool/postfix`): move
`MilterSocket` there or listen on TCP with
`'MilterSocket' => 'inet:7357@localhost'`.

### User and group

The packages create the ClamAV users. `manage_user` creates `user` and
`group` before them, for example to set their identifiers, or adds
supplementary groups, for example for an MTA filter reading the files of
another user:

```puppet
class { 'clamav':
  manage_user => true,
  uid         => 496,
  gid         => 496,
  groups      => ['amavis'],
}
```

The user is `clamav` on Debian, Ubuntu and Arch Linux and `clamscan`, the
user of clamd, on the RedHat family. The groups the user already belongs to
are kept.

### Hiera

```yaml
clamav::clamd::options:
  MaxThreads: 4
  ExcludePath:
    - '^/proc/'
    - '^/sys/'
clamav::freshclam::mode: 'timer'
clamav::freshclam::on_calendar: '*-*-* 03:30:00'
clamav::milter::options:
  OnInfected: 'Reject'
```

```puppet
include clamav::clamd
include clamav::freshclam
include clamav::milter
```

## Upgrading from edestecd-clamav 2.x

Version 3.0.0 is published as `arakmar-clamav` and breaks the interface of
edestecd-clamav. The class names of the resources change, and so do the
generated files: review the diff of a first run in noop mode.

| Before                                                              | Now                                                                                   |
|---------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `manage_clamd`, `manage_freshclam`, `manage_clamav_milter`          | declare `clamav::clamd`, `clamav::freshclam`, `clamav::milter`                        |
| `clamd_package`, `clamd_version`, `clamd_config`                    | `clamav::clamd::package_name`, `package_ensure`, `config_file`                        |
| `clamd_service`, `clamd_service_ensure`, `clamd_service_enable`     | `clamav::clamd::service_name`, `service_ensure`, `service_enable`                     |
| `clamd_options`                                                     | `clamav::clamd::options`                                                              |
| `freshclam_*`                                                       | `clamav::freshclam::*`, as above                                                      |
| `clamav_milter_*`                                                   | `clamav::milter::*`, as above                                                         |
| `clamav_package`, `clamav_version`                                  | `package_name`, `package_ensure`                                                      |
| `freshclam_sysconfig`, `freshclam_delay`                            | removed, they only applied to EL 7                                                    |
| `user => false`, `group => false`                                   | `manage_user` manages both, `false` by default as before                              |
| `uid`, `gid` defaulting to 496                                      | undef, the user and group get system identifiers                                      |
| Debian 7 defaults (`MaxThreads 12`, `StreamMaxLength 25M`...) on every OS | the packaged services settings only, ClamAV defaults for the rest              |
| `true`/`false` written as is                                        | `yes`/`no`                                                                            |
| option names such as `'# comment'`                                  | refused, names must be ClamAV option names                                            |
| EL milter on `inet:8890@localhost`, clamd on `tcp:127.0.0.1`        | local sockets of the packages, see [Milter](#milter)                                  |
| EL packages `clamav-scanner-systemd`, `clamav-update`, `clamav-milter-systemd` | `clamd`, `clamav-freshclam`, `clamav-milter`                               |
| `Package['clamd']`, `Package['freshclam']`, `Package['clamav_milter']` | packages titled after their names, for example `Package['clamav-daemon']`; prefer `Class['clamav::clamd']` |
| `File['clamd.conf']`, `File['freshclam.conf']`, `File['clamav-milter.conf']` | files titled after their paths                                      |
| `Service['clamd']`, `Service['freshclam']`, `Service['clamav_milter']` | services titled after their names                                                 |

To keep the former defaults, pass them in `options`. The configurations
shipped by the Debian packages, which they come from, still pass the ClamAV
checks, but several of their options are deprecated since ClamAV 0.101:

| Deprecated                         | Replacement                  |
|------------------------------------|------------------------------|
| `AlgorithmicDetection`             | `HeuristicAlerts`            |
| `ArchiveBlockEncrypted`            | `AlertEncrypted`             |
| `OLE2BlockMacros`                  | `AlertOLE2Macros`            |
| `PhishingAlwaysBlockSSLMismatch`   | `AlertPhishingSSLMismatch`   |
| `PhishingAlwaysBlockCloak`         | `AlertPhishingCloak`         |
| `PartitionIntersection`            | `AlertPartitionIntersection` |
| `DatabaseMirror db.local.clamav.net` | `database.clamav.net` only |
| milter `Whitelist`                 | `AllowList`, or `allow_list` |

A freshclam daemon stopped in favour of a cron job can become
`mode => 'timer'` with `on_calendar`.

## Limitations

* On Debian, Ubuntu and Arch Linux clamd is started by
  `clamav-daemon.socket`, which listens on `/run/clamav/clamd.ctl`: clamd
  uses that socket whatever `LocalSocket`, `LocalSocketGroup` and
  `LocalSocketMode` say. Override the socket unit to listen elsewhere.
* clamd does not start until freshclam has downloaded the databases, which
  can take a few minutes after the first run.
* clamav-milter cannot check its configuration, an invalid file makes the
  service fail. Arch Linux ships no unit for it: `manage_service` is false
  there.
* The validation runs the installed `/usr/sbin/clamd` and
  `/usr/bin/freshclam`: install ClamAV from the packages, or set
  `validate => false`.

## Development

```
pdk validate
pdk test unit
pdk bundle exec rake strings:generate:reference
```

When ClamAV is installed, the unit tests also check the rendered files with
clamd, freshclam and clamconf; point `CLAMD`, `FRESHCLAM` and `CLAMCONF` at
other executables to test another release, and set `CLAMAV_VALIDATE` to
fail rather than skip when they are missing.

GitHub Actions run the static validations, RuboCop, a REFERENCE.md freshness
check and the unit tests on every pull request and push to `master`, and
check the rendered files with ClamAV 1.4.6, 1.5.4 and the latest release
(`.github/workflows/ci.yml`, modelled on the
[Vox Pupuli](https://github.com/voxpupuli/gha-puppet) workflows).

Pushing a `v<version>` tag runs the CI on the tagged commit, then publishes
the module to the Puppet Forge and creates a GitHub release through the Vox
Pupuli reusable release workflow (`.github/workflows/release.yml`). The
repository needs a `release` environment and the `PUPPET_FORGE_USERNAME` and
`PUPPET_FORGE_API_KEY` secrets; bump `metadata.json` to the tagged version
first.

This module is licensed under the GPL-3.0-or-later license, see
[LICENSE](LICENSE). It was started by Chris Edester as
[edestecd-clamav](https://github.com/edestecd/puppet-clamav).
