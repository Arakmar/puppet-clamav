# @summary Installs ClamAV
#
# Installs the base package, with the command line scanner and the
# libraries, from EPEL on the RedHat family. The daemons are managed by
# their own classes, which include this one: clamav::clamd,
# clamav::freshclam and clamav::milter.
#
# The OS-specific defaults come from the module data.
#
# @example The command line scanner only
#   include clamav
#
# @example The scanner daemon and its database updates
#   include clamav::clamd
#   include clamav::freshclam
#
# @example Add the ClamAV user to the group of an MTA filter
#   class { 'clamav':
#     manage_user => true,
#     groups      => ['amavis'],
#   }
#
# @param user
#   ClamAV user, managed with `manage_user`.
# @param group
#   Primary group of `user`.
# @param home
#   Home directory of `user`.
# @param shell
#   Shell of `user`.
# @param manage_repo
#   Whether to set up EPEL, where the RedHat family gets ClamAV from.
# @param package_name
#   Name of the base package.
# @param package_ensure
#   Ensure value of the base package.
# @param manage_user
#   Whether to manage `user` and `group`, before the packages create them.
#   For example to give them fixed identifiers or supplementary groups.
# @param uid
#   UID of `user`, a system UID is allocated when undef.
# @param gid
#   GID of `group`, a system GID is allocated when undef.
# @param comment
#   Comment of `user`.
# @param groups
#   Supplementary groups of `user`. The groups it already belongs to are
#   kept.
class clamav (
  String[1] $user,
  String[1] $group,
  Stdlib::Absolutepath $home,
  Stdlib::Absolutepath $shell,
  Boolean $manage_repo,
  String[1] $package_name = 'clamav',
  String[1] $package_ensure = 'installed',
  Boolean $manage_user = false,
  Optional[Integer[0]] $uid = undef,
  Optional[Integer[0]] $gid = undef,
  Optional[String[1]] $comment = undef,
  Array[String[1]] $groups = [],
) {
  contain clamav::install

  if $manage_user {
    contain clamav::user

    Class['clamav::user'] -> Class['clamav::install']
  }
}
