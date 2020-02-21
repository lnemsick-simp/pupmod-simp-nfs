require 'spec_helper'

# Testing private nfs::idmapd::server via nfs
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }

  context 'with nfs::idmapd=true' do
    let(:hieradata) { 'idmapd_server_enabled' }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::idmapd::server') }
    it { is_expected.to create_class('nfs::idmapd::config') }
    it { is_expected.to create_service('nfs-idmapd.service').with( {
        :ensure     => 'running',
        :enable     => true,
        :hasrestart => true
      } )
    }

    it { is_expected.to create_exec('unmask_nfs-idmapd.service').with( {
        :command => '/usr/bin/systemctl unmask nfs-idmapd.service',
        :onlyif  => '/usr/bin/systemctl status nfs-idmapd.service | /usr/bin/grep -qw masked',
      } )
    }
  end

  context 'with nfs::idmapd=false' do
    let(:hieradata) { 'idmapd_server_disabled' }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::idmapd::server') }
    it { is_expected.to_not create_class('nfs::idmapd::config') }
    it { is_expected.to create_service('nfs-idmapd.service').with( {
        :ensure     => 'stopped',
      } )
    }

    it { is_expected.to create_exec('mask_nfs-idmapd.service').with( {
        :command => '/usr/bin/systemctl mask nfs-idmapd.service',
        :unless  => '/usr/bin/systemctl status nfs-idmapd.service | /usr/bin/grep -qw masked',
      } )
    }
  end
end
