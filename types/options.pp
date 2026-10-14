# @summary The options of a ClamAV configuration file, keyed by name
#
# The names are those of clamd.conf(5), freshclam.conf(5) and
# clamav-milter.conf(5). An undef value leaves the option out of the file,
# which removes a default of the module.
#
# @example
#   { 'MaxThreads' => 4, 'ScanPDF' => true, 'ExcludePath' => ['^/proc/', '^/sys/'], 'LogSyslog' => undef }
type Clamav::Options = Hash[Pattern[/\A[A-Z][A-Za-z0-9]*\z/], Optional[Clamav::Value]]
