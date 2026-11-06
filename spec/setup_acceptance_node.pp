# Applied on each acceptance node before the tests: the client of clamd is a
# package of its own on Debian and Ubuntu.
if $facts['os']['family'] == 'Debian' {
  package { 'clamdscan':
    ensure => installed,
  }
}
