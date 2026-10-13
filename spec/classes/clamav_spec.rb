# frozen_string_literal: true

require 'spec_helper'

describe 'clamav' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      redhat = os_facts[:os]['family'] == 'RedHat'

      let(:facts) { os_facts }
      let(:user) do
        {
          'Archlinux' => { name: 'clamav', home: '/', shell: '/usr/bin/nologin' },
          'Debian' => { name: 'clamav', home: '/var/lib/clamav', shell: '/bin/false' },
          'RedHat' => { name: 'clamscan', home: '/', shell: (facts[:os]['release']['major'] == '8') ? '/sbin/nologin' : '/usr/sbin/nologin' },
        }.fetch(facts[:os]['family'])
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('clamav::install') }
        it { is_expected.to contain_package('clamav').with_ensure('installed') }
        it { is_expected.not_to contain_class('clamav::user') }
        it { is_expected.not_to contain_user(user[:name]) }
        it { is_expected.not_to contain_class('clamav::clamd') }
        it { is_expected.not_to contain_class('clamav::freshclam') }
        it { is_expected.not_to contain_class('clamav::milter') }

        if redhat
          it { is_expected.to contain_class('epel').that_comes_before('Package[clamav]') }
        else
          it { is_expected.not_to contain_class('epel') }
        end
      end

      context 'without the repository' do
        let(:params) { { manage_repo: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('epel') }
      end

      context 'with another package' do
        let(:params) { { package_name: 'clamav-custom', package_ensure: 'latest' } }

        it { is_expected.to contain_package('clamav-custom').with_ensure('latest') }
        it { is_expected.not_to contain_package('clamav') }
      end

      context 'with the user managed' do
        let(:params) { { manage_user: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('clamav::user').that_comes_before('Class[clamav::install]') }
        it { is_expected.to contain_group(user[:name]).with_ensure('present').with_gid(nil).with_system(true) }

        it do
          is_expected.to contain_user(user[:name])
            .with_ensure('present')
            .with_uid(nil)
            .with_gid(user[:name])
            .with_groups([])
            .with_comment(nil)
            .with_home(user[:home])
            .with_shell(user[:shell])
            .with_system(true)
        end
      end

      context 'with the user managed with fixed identifiers' do
        let(:params) do
          {
            manage_user: true,
            user: 'av',
            group: 'av',
            uid: 496,
            gid: 497,
            comment: 'ClamAV',
            groups: %w[amavis postfix],
            home: '/var/lib/av',
            shell: '/sbin/nologin',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_group('av').with_gid(497) }

        it do
          is_expected.to contain_user('av')
            .with_uid(496)
            .with_gid('av')
            .with_groups(%w[amavis postfix])
            .with_comment('ClamAV')
            .with_home('/var/lib/av')
            .with_shell('/sbin/nologin')
        end
      end
    end
  end
end
