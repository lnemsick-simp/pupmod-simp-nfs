# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::firewall::nfsv3
{
  assert_private()

  include 'iptables'

  $_rpcbind_port = 111
  $_base_ports = [
    $_rpcbind_port,
    $::nfs::nfsd_port,
    $::nfs::rquotad_port,
    $::nfs::mountd_port,
    $::nfs::statd_port
  ]

  $_tcp_ports = $_base_ports + $::nfs::lockd_port
  iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
    trusted_nets => $::nfs::server::trusted_nets,
    dports       => $_tcp_ports
  }

  $_udp_ports = $_base_ports + $::nfs::lockd_udp_port
  iptables::listen::udp { 'nfs_client_udp_ports':
    trusted_nets => $::nfs::server::trusted_nets,
    dports       => $_udp_ports
  }
}
