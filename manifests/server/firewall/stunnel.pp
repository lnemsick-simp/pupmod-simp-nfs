# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::firewall::stunnel
{
  assert_private()

  include 'iptables'

  iptables::listen::tcp_stateful{ 'nfs_client_tcp_ports':
    trusted_nets => $::nfs::server::stunnel::trusted_nets,
    dports       => $::nfs::server::stunnel::stunnel_port_override
  }

  # FIXME NFSv3 client sends NSM (network status manager) notifications are over UDP.
  # but listen for server NSM notificationson both UDP and TCP.  Need to open up
  # the client to server UDP port for that?
}
