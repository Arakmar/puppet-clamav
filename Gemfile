source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  gem 'voxpupuli-test', '~> 15.0', require: false
  gem 'puppet_metadata', '~> 6.4', require: false
  # facterdb filters its fact sets with jgrep, which json 3 broke
  gem 'json', '< 3', require: false
end

group :release do
  gem 'voxpupuli-release', '~> 5.5', require: false
end

gem 'rake', require: false

gem 'openvox', ENV.fetch('OPENVOX_GEM_VERSION', ['>= 8', '< 10']), require: false, groups: [:test]
