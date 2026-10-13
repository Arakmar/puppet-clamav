# @summary Manages the ClamAV user and group
#
# @api private
class clamav::user {
  assert_private()

  group { $clamav::group:
    ensure => present,
    gid    => $clamav::gid,
    system => true,
  }

  user { $clamav::user:
    ensure  => present,
    uid     => $clamav::uid,
    gid     => $clamav::group,
    groups  => $clamav::groups,
    comment => $clamav::comment,
    home    => $clamav::home,
    shell   => $clamav::shell,
    system  => true,
  }
}
