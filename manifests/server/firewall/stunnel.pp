# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::firewall::stunnel
{
  assert_private()

  include 'iptables'

  iptables::listen::tcp_stateful{ 'nfs_client_tcp_ports':
    trusted_nets => $nfs::server::stunnel::trusted_nets,
    dports       => $nfs::server::stunnel::stunnel_port_override
  }

  if $nfs::nfsv3 {
    # According to the nfs man page, NFSv3 clients send NSM (network status
    # manager) notifications over UDP always.
    iptables::listen::udp { 'nfs_client_status_udp_port':
      trusted_nets => $nfs::server::stunnel::trusted_nets,
      dports       => $nfs::statd_port
    }
  }
}
