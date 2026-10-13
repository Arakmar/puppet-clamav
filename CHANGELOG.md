# Changelog

All notable changes to this project will be documented in this file.

## Release 3.0.0

First release published as `arakmar-clamav`, the continuation of
edestecd-clamav 2.0.0, rewritten for Puppet 8 and the ClamAV packages of
current distributions. See the upgrade table of the README.

**Breaking changes**

* Puppet 8 (or OpenVox 8), puppetlabs/stdlib 9.x or 10.x, puppet/systemd
  >= 8.2.0 and, on the RedHat family, puppet/epel 5.x or 6.x are required.
  Supported systems are EL 8 to 10, Debian 12 and 13, Ubuntu 22.04 and
  24.04 and Arch Linux; EL 6 and 7, Debian 8 and 9 and Ubuntu 14.04 and
  16.04 are dropped.
* The `manage_clamd`, `manage_freshclam` and `manage_clamav_milter`
  switches and the prefixed parameters of class `clamav` give way to the
  `clamav::clamd`, `clamav::freshclam` and `clamav::milter` classes
  (`clamav::clamav_milter` is renamed), each with `package_name`,
  `package_ensure`, `config_file`, `options`, `service_name`,
  `service_ensure` and `service_enable`. `clamav_package` and
  `clamav_version` become `package_name` and `package_ensure`.
  `params.pp` is replaced by module data.
* The default options only hold what the packaged services rely on
  (sockets, users, log and pid files, database directory and mirror)
  instead of the Debian 7 configuration applied to every distribution:
  ClamAV defaults apply to everything else, for example `MaxThreads`,
  `StreamMaxLength`, `MaxScanSize` and `MaxFileSize`. Booleans are written
  `yes`/`no`. Option names and values are typed, so the `# comment` keys
  the template used to accept are refused.
* The RedHat family uses the package names of EPEL 8+ (`clamd`,
  `clamav-freshclam`, `clamav-milter`) rather than the EL 7 names they
  provide, and its milter listens on the local
  socket of the package instead of `inet:8890@localhost`, connecting to the
  local clamd socket instead of `tcp:127.0.0.1`. `freshclam_sysconfig` and
  `freshclam_delay` (EL 7) are removed.
* `uid` and `gid` default to undef (system identifiers) instead of 496,
  `groups` is an array, and `user => false`/`group => false` are replaced
  by `manage_user`, which manages both.
* Packages, files and services are titled after their names and paths
  instead of `clamd`, `freshclam`, `clamav_milter`, `clamd.conf`...
* The Beaker acceptance tests and the Travis configuration are removed.

**Features**

* Arch Linux support.
* clamd and freshclam check their configuration file before it is
  replaced (`validate`).
* `clamav::freshclam` can run from the packaged
  `clamav-freshclam-once.timer` instead of the daemon (`mode => 'timer'`),
  on a schedule set by `on_calendar` and `timer_entry`.
* `clamav::milter` manages the file of its `AllowList` option from
  `allow_list`.
* `manage_service` on each component, for example where the service is run
  by something else.
* Type aliases, puppet-strings documentation (REFERENCE.md), rspec-puppet
  tests checking the rendered files with ClamAV 1.4 and 1.5, GitHub Actions
  CI and Forge release workflows.

**Bugfixes**

* The default options no longer use the options deprecated since ClamAV
  0.101 (`AlgorithmicDetection`, `ArchiveBlockEncrypted`,
  `OLE2BlockMacros`, `PhishingAlwaysBlockSSLMismatch`,
  `PhishingAlwaysBlockCloak`) nor the obsolete `db.local.clamav.net`
  mirror.
* `/etc/sysconfig/freshclam` is no longer written on EL 8+, where nothing
  reads it.

## 2020-08-25 (2.0.0)  Chris Edester
* PDK support at 1.18.0
* Puppet 5/6ish support
* Drop Puppet 3 support
* Update puppetlabs/stdlib dependency
* Switch to puppet/epel dependency

## 2016-08-10 (1.0.0)  Chris Edester
* WARNING: Major revision, will most likely change your configs, especially on RedHat (Please test first)
* Refactor private class params and specs
* RedHat uses the same template and hash as Debian, allowing you to unset options by passing undef
* RedHat 7.x support
* Default config options are the same across all supported OSes
* Manage /etc/sysconfig/freshclam on RedHat 7
* Comply with Puppet 4 strict variables

## 2016-05-08 (0.5.0)  Chris Edester
* Move the freshclam package ordering out of service definition
* Add enable param to clamd and freshclam services
* Adding option to set specific version number for package installs

## 2015-11-29 (0.4.0)  Chris Edester
* add tests
* parameters to set service ensure

## 2015-06-01 (0.3.1)  Daniel Rosenbloom
* fixes #7 no need to validate $groups if it is still undef

## 2015-03-27 (0.3.0)  Chris Edester
* fixes #5 Hash iteration order in ruby 1.8.7
* Allow to unset default config_options

## 2015-03-19 (0.2.3)  Patrick Schönfeld
* Allow specification of groups for clamav user

## 2015-03-19 (0.2.2)  Chris Edester
* fix lint errors and add rubocop

## 2015-02-04 (0.2.1)  Chris Edester
* update license identifier in metadata.json

## 2015-02-04 (0.2.0)  Chris Edester
* try to fix lint errors

## 2015-02-04 (0.1.4)  Chris Edester
* fixes #2 Use Debian versioning on operatingsystem Debian

## 2015-02-04 (0.1.3)  Chris Edester
* fixes #1 Make EPEL repo install optional

## 2014-10-29 (0.1.2)  Chris Edester
* puppet lint checks and improved version comparison

## 2014-09-15 (0.1.1)  Chris Edester
* compatability with puppet 3.7 and future parser

## 2014-07-01 (0.1.0)  Chris Edester
* Document and publish

## 2014-06-04 (0.0.7)  Chris Edester
* Debian config file options working

## 2014-06-04 (0.0.5)  Chris Edester
* RedHat config file options working

## 2014-06-04 (0.0.4)  Chris Edester
* Start work on config options

## 2014-06-02 (0.0.3)  Chris Edester
* Add user class and base templates

## 2014-06-02 (0.0.2)  Chris Edester
* Add clamd and freshclam classes

## 2014-05-30 (0.0.1)  Chris Edester
* Initial Commit of default files etc.
