require 'spec_helper'

# Testing private nfs::server::firewall::nfsv3and4 class via nfs class
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }
  let(:params) { {
    # nfs class params
    :is_server    => true,
    :nfsv3        => true,
    :firewall     => true,
    :trusted_nets => [ '1.2.3.0/24' ]
  }}

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
  it { is_expected.to create_class('iptables') }
  it { is_expected.to create_iptables__listen__tcp_stateful('nfs_client_tcp_ports').with( {
      :trusted_nets => params[:trusted_nets],
      :dports       => [111, 2049, 875, 20048, 662, 32803],
  } ) }

  it { is_expected.to create_iptables__listen__udp('nfs_client_udp_ports').with( {
      :trusted_nets => params[:trusted_nets],
      :dports       => [111, 2049, 875, 20048, 662, 32769],
  } ) }
end
