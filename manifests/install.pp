# @summary Installs the ClamAV base package
#
# @api private
class clamav::install {
  assert_private()

  if $clamav::manage_repo {
    include epel

    Class['epel'] -> Package[$clamav::package_name]
  }

  package { $clamav::package_name:
    ensure => $clamav::package_ensure,
  }
}
