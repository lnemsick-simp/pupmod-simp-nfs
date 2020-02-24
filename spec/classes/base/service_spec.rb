require 'spec_helper'

# Testing private nfs::server::service class via nfs class
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }

  context 'NFSv3' do
    context 'with nfs::nfsv3 false' do
      let(:params) { {} } # nfs::nfsv3 default is false
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::base::service') }
      it { is_expected.to create_service('rpc-statd.service').with_ensure('stopped') }
      it { is_expected.to create_exec('mask_rpc-statd.service').with( {
        :command => '/usr/bin/systemctl mask rpc-statd.service',
        :unless  => '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked'
      } ) }
    end

    context 'with nfs::nfsv3 true' do
      let(:params) { {
        # nfs class params
        :nfsv3 => true
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::base::service') }
      it { is_expected.to create_service('rpcbind.service').with( {
        :ensure     => 'running',
        :enable     => true,
        :hasrestart => true
      } ) }

      it { is_expected.to create_service('rpc-statd.service').with( {
        :ensure     => 'running',
        :hasrestart => true
      } ) }

      it { is_expected.to create_svckill__ignore('rpc-statd-notify') }
      it { is_expected.to create_exec('unmask_rpc-statd.service').with( {
        :command => '/usr/bin/systemctl unmask rpc-statd.service',
        :onlyif  => '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked'
      } ) }
    end
  end

  context 'Secure NFS' do
    context 'with nfs::secure_nfs false' do
      let(:params) { {} } # nfs::secure_nfs default is false
      it { is_expected.to create_class('nfs::base::service') }
      it { is_expected.to create_service('rpc-gssd.service').with_ensure('stopped') }
      it { is_expected.to create_exec('mask_rpc-gssd.service').with( {
        :command => '/usr/bin/systemctl mask rpc-gssd.service',
        :unless  => '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked'
      } ) }
    end

    context 'with nfs::secure_nfs true' do
      context 'with nfs::gssd_use_gss_proxy false' do
        let(:params) { {
          # nfs class params
          :secure_nfs         => true,
          :gssd_use_gss_proxy => false
        }}

        it { is_expected.to create_class('nfs::base::service') }
        it { is_expected.to create_service('rpc-gssd.service').with( {
          :ensure     => 'running',
          :hasrestart => true
        } ) }

        it { is_expected.to create_exec('unmask_rpc-gssd.service').with( {
          :command => '/usr/bin/systemctl mask rpc-gssd.service',
          :onlyif  => '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked'
        } ) }
      end

      context 'with nfs::gssd_use_gss_proxy true' do
        let(:params) { {
          # nfs class params
          :secure_nfs => true
          # nfs::gssd_use_gss_proxy default is true
        }}

        it { is_expected.to create_class('nfs::base::service') }
        it { is_expected.to create_service('rpc-gssd.service')}
        it { is_expected.to create_exec('unmask_rpc-gssd.service') }
        it { is_expected.to create_service('gssproxy.service').with( {
          :ensure     => 'running',
          :enable     => true,
          :hasrestart => true
        } ) }
      end
    end
  end
end
