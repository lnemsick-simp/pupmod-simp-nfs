require 'spec_helper'

# Testing private nfs::server::service class via nfs class
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }

  let(:params) { {
    # nfs class params
    :is_server => true,
  }}

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_class('nfs::server::service') }
  it { is_expected.to create_service('nfs-server.service').with( {
    :ensure     => 'running',
    :enable     => true,
    :hasrestart => false,
    :restart    => 'systemctl restart nfs-utils.service nfs-server.service'
  } ) }

  it { is_expected.to create_svckill__ignore('nfs-mountd') }

  it { is_expected.to create_service('rpcbind.service').with( {
    :ensure     => 'running',
    :enable     => true,
    :hasrestart => true
  } ) }

  it { is_expected.to create_service('rpc-rquotad.service').with( {
    :ensure     => 'running',
    :enable     => true,
    :hasrestart => true
  } ) }

end
