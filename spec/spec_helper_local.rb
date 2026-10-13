# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Helpers reading the ClamAV configuration files of the catalogue and
# checking them with ClamAV itself when it is installed.
module ClamavSpecHelpers
  SEARCH_PATH = (ENV['PATH'].split(File::PATH_SEPARATOR) + ['/usr/local/sbin', '/usr/sbin', '/sbin']).uniq.freeze

  # The ClamAV executable checking the rendered files: $CLAMD, $FRESHCLAM
  # or $CLAMCONF, or the one found in the PATH and the sbin directories.
  # With CLAMAV_VALIDATE set, a missing executable fails these examples
  # instead of skipping them.
  def self.executable(name)
    ENV[name.upcase] || SEARCH_PATH.map { |dir| File.join(dir, name) }.find { |path| File.executable?(path) }
  end

  # Content of a file resource of the catalogue.
  def rendered_content(path)
    catalogue.resource('File', path)[:content]
  end

  # The executable checking the configuration files of `kind` (clamd,
  # freshclam or milter), skipping the example when it is missing.
  # clamav-milter cannot check its configuration, clamconf parses it
  # instead.
  def clamav_checker(kind)
    program = { 'clamd' => 'clamd', 'freshclam' => 'freshclam', 'milter' => 'clamconf' }.fetch(kind)
    executable = ClamavSpecHelpers.executable(program)
    if executable.nil?
      raise "#{program} not found" if ENV['CLAMAV_VALIDATE']

      skip "#{program} is not installed"
    end
    executable
  end

  # Checks a configuration file of `kind` like the validate_cmd of the
  # module does. Returns the output of the check, an error message when
  # `valid` is false.
  def expect_valid_for_clamav(kind, content, valid: true)
    executable = clamav_checker(kind)

    Dir.mktmpdir('clamav') do |dir|
      if kind == 'milter'
        File.write(File.join(dir, 'clamav-milter.conf'), content)
        output, status = Open3.capture2e(executable, '-c', dir)
        # clamconf reports the errors without failing
        expect(status).to be_success, output
        expect(output.match?(%r{^ERROR})).to be(!valid), output
      else
        file = File.join(dir, "#{kind}.conf")
        File.write(file, content)
        output, status = Open3.capture2e(executable, "--config-file=#{file}", '--version')
        expect(status.success?).to be(valid), output
      end
      output
    end
  end
end

RSpec.configure do |c|
  c.include ClamavSpecHelpers
end
