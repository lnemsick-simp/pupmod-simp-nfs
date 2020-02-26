# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) DEFINE**
#
# A helper for setting up the cross-system connectivity parts of a mount
#
# **This should NOT be called from outside ``nfs::client::mount``**
#
#
# @param nfs_server
# @param nfs_version
# @param nfsd_port
# @param firewall
# @param stunnel
#   * Unused when `nfs_version` is 3
#
# @param stunnel_nfsd_port
#   * Unused when `stunnel` is false or `nfs_version` is 3
#
# @param stunnel_socket_options
#   * Unused when `stunnel` is false or `nfs_version` is 3
#
# @param stunnel_verify
#   * Unused when `stunnel` is false or `nfs_version` is 3
#
# @param stunnel_wantedby
#   * Unused when `stunnel` is false or `nfs_version` is 3
#
# @param tcpwrappers
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount::connection (
  Simplib::Ip   $nfs_server,
  Integer[3,4]  $nfs_version,
  Simplib::Port $nfsd_port,
  Boolean       $firewall,
  Boolean       $stunnel,
  Simplib::Port $stunnel_nfsd_port,
  Array[String] $stunnel_socket_options,
  Integer       $stunnel_verify,
  Array[String] $stunnel_wantedby,
  Boolean       $tcpwrappers,
) {

  # This is only meant to be called from inside nfs::client::mount
  assert_private()

  if $stunnel and ($nfs_version == 4) {
    # It is possible that this is called for multiple mounts on the same server.
    # stunnel-related firewall and tcpwrappers settings handled by the
    # stunnel::instance, itself.
    ensure_resource('nfs::client::stunnel',
      "${nfs_server}:${nfsd_port}",
      {
        nfs_server             => $nfs_server,
        nfsd_accept_port       => $nfsd_port,
        nfsd_connect_port      => $stunnel_nfsd_port,
        stunnel_socket_options => $stunnel_socket_options,
        stunnel_verify         => $stunnel_verify,
        stunnel_wantedby       => $stunnel_wantedby,
        firewall               => $firewall,
        tcpwrappers            => $tcpwrappers
      }
    )
  } elsif $firewall  {
    # Open up the firewall for incoming, side-band NFS channels.
    include 'iptables'

    # WORK AROUND iptables::listen::xxx issue with invalid firewalld services
    # filenames caused by rules with IP addresses
    $_safe_nfs_server = regsubst($nfs_server, '[\.:]', '_', 'G')

    if ($nfs_version == 4) {
      # Set up the NFSv4.0 delegation callback port IPTables opening.  This is
      # only needed for NFSv4.0, because, beginning with NFSv4.1, delegation
      # does not require a side channel. However, unless the mount specifies
      # the minor NFSv4 version, we cannot be assured NFSv4.0 will not be the
      # version used. This is because in the absence of a specified minor NFS
      # version, the client negotiates with the NFS server to determine the
      # minor version.

      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_callback_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          # the port to use is communicated via the main nfsd channel, so no
          # need for rpcbind
          dports       => [$nfs::client::callback_port]
        }
      )
    } else {
      # In NFSv3, the NFS server will reach out to the client in NLM and NSM
      # protos (i.e., locking and recovery from locking upon server/client
      # reboot). The NFS server uses rpcbind to figure out the client's ports
      # for this communication.
      #
      # TODO Restrict source port to the server's configured (not ephemeral)
      # outgoing statd and statd-notify ports as appropriate.
      #
      $_rpcbind_port = 111
      $_tcp_status_ports = [
        $_rpcbind_port,
        $nfs::lockd_port,
        $nfs::statd_port
      ]
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_status_tcp_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => $_tcp_status_ports
        }
      )

      $_udp_status_ports = [
        $_rpcbind_port,
        $nfs::lockd_udp_port,
        $nfs::statd_port
      ]
      ensure_resource('iptables::listen::udp',
        "nfs_status_udp_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => $_udp_status_ports
        }
      )
    }
  }
}
