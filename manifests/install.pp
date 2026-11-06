# @summary Installs the ClamAV base package
#
# @api private
class clamav::install {
  assert_private()

  if $clamav::manage_repo {
    include epel

    Class['epel'] -> Package[$clamav::package_name]

    # Only enabled: the repository is defined by the release package of the OS
    if $clamav::crb_repo {
      ensure_resource('yumrepo', $clamav::crb_repo, { 'enabled' => '1' })

      Yumrepo[$clamav::crb_repo] -> Package[$clamav::package_name]
    }
  }

  package { $clamav::package_name:
    ensure => $clamav::package_ensure,
  }
}
