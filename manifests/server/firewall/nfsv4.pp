# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::firewall::nfsv4
{
  assert_private()

  include 'iptables'

  $_ports = [
    111, # rpcbind port; rpcbind required for rpc.rquotad
    $::nfs::nfsd_port,
    $::nfs::rquotad_port
  ]

  iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
    trusted_nets => $::nfs::server::trusted_nets,
    dports       => $_ports
  }

  iptables::listen::udp { 'nfs_client_udp_ports':
    trusted_nets => $::nfs::server::trusted_nets,
    dports       => $_ports
  }

}
