# @summary Renders a ClamAV configuration file
#
# Writes one `<Name> <value>` line per option, in alphabetical order, which
# also puts `LogFileMaxSize` before `LogRotate` as ClamAV requires. An array
# repeats the option once per value. Booleans are written `yes` and `no` and
# undef options are left out.
#
# @param options The ClamAV options.
# @return [String] The content of the configuration file.
function clamav::to_config(Clamav::Options $options) >> String {
  $lines = $options.keys.sort.map |$name| {
    [$options[$name]].flatten.filter |$value| { $value =~ NotUndef }.map |$value| {
      $rendered = $value ? {
        true    => 'yes',
        false   => 'no',
        default => String($value),
      }
      "${name} ${rendered}"
    }
  }.flatten

  "${(['# Managed by Puppet'] + $lines).join("\n")}\n"
}
