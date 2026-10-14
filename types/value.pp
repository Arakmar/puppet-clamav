# @summary The value of a ClamAV option
#
# Booleans are written `yes` and `no`. An array repeats the option once per
# value, for the options ClamAV accepts several times such as
# `DatabaseMirror`, `ExcludePath` or `LocalNet`. A value cannot span several
# lines.
#
# @example
#   true
#   3310
#   '/run/clamav/clamd.ctl'
#   ['^/proc/', '^/sys/']
type Clamav::Value = Variant[
  Boolean,
  Integer,
  Pattern[/\A[^\r\n]+\z/],
  Array[Variant[Integer, Pattern[/\A[^\r\n]+\z/]], 1],
]
