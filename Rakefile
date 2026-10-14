# frozen_string_literal: true

begin
  require 'voxpupuli/test/rake'
rescue LoadError
  # only available if gem group test is installed
end

begin
  require 'voxpupuli/release/rake_tasks'
rescue LoadError
  # only available if gem group release is installed
else
  GCGConfig.user = 'Arakmar'
  GCGConfig.project = 'puppet-clamav'
end
