# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::firewall::stunnel
{
  assert_private()

  include 'iptables'

  # stunnels will take care of their own ports. Here, we just have to deal
  # with stragglers that are outside the stunnels.

  # rpcbind is required for rquotad
  iptables::listen::tcp_stateful{ 'nfs_client_rpcbind_port':
    trusted_nets => $nfs::server::trusted_nets,
    dports       => [ 111 ]
  }

  if $nfs::nfsv3 {
    # According to the nfs man page, NFSv3 clients send NSM (network status
    # manager) notifications over UDP always.
    iptables::listen::udp { 'nfsv3_client_status_udp_port':
      trusted_nets => $nfs::server::trusted_nets,
      dports       => [ $nfs::statd_port ]
    }
  }
}
