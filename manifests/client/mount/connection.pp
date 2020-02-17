# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# A helper for setting up the cross-system connectivity parts of a mount
#
# **This should NOT be called from outside ``nfs::client::mount``**
#
# All parameters map to their counterparts in ``nfs::client::mount``
#
# @param nfs_server
# @param nfs_version
# @param nfs_port
# @param v4_remote_port
# @param stunnel
# @param stunnel_wantedby
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount::connection (
  Simplib::Ip   $nfs_server,
  Integer[3,4]  $nfs_version,
  Simplib::Port $lockd_port,
  Simplib::Port $mountd_port,
  Simplib::Port $nfsd_port,
  Simplib::Port $rquotad_port,
  Simplib::Port $statd_port,
  Simplib::Port $client_callback_port,
  Simplib::Port $client_lockd_port,
  Simplib::Port $client_lockd_udp_port,
  Simplib::Port $client_statd_port,
  Boolean       $firewall,
  Boolean       $stunnel,
  Simplib::Port $stunnel_lockd_port,
  Simplib::Port $stunnel_mountd_port,
  Simplib::Port $stunnel_nfsd_port,
  Simplib::Port $stunnel_rquotad_port,
  Simplib::Port $stunnel_statd_port,
  Array[String] $stunnel_socket_options,
  Integer       $stunnel_verify,
  Array[String] $stunnel_wantedby,
  Boolean       $tcpwrappers,
) {

  # This is only meant to be called from inside nfs::client::mount
  assert_private()

  if $stunnel {
    if $nfs_version == 3 {
      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('nfs::client::stunnel::nfsv3',
        "${nfs_server}:${nfsd_port}",
        {
          nfs_server             => $nfs_server,
          lockd_accept_port      => $lockd_port,
          lockd_connect_port     => $stunnel_lockd_port,
          mountd_accept_port     => $mountd_port,
          mountd_connect_port    => $stunnel_mountd_port,
          nfsd_accept_port       => $nfsd_port,
          nfsd_connect_port      => $stunnel_nfsd_port,
          rquotad_accept_port    => $rquotad_port,
          rquotad_connect_port   => $stunnel_rquotad_port,
          statd_accept_port      => $statd_port,
          statd_connect_port     => $stunnel_statd_port,
          stunnel_socket_options => $stunnel_socket_options,
          stunnel_verify         => $stunnel_verify,
          stunnel_wantedby       => $stunnel_wantedby,
          firewall               => $firewall,
          tcpwrappers            => $tcpwrappers,
        }
      )
    }
    else {
      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('nfs::client::stunnel::nfsv4',
        "${nfs_server}:${nfsd_port}",
        {
          nfs_server             => $nfs_server,
          nfsd_accept_port       => $nfsd_port,
          nfsd_connect_port      => $stunnel_nfsd_port,
          rquotad_accept_port    => $rquotad_port,
          rquotad_connect_port   => $stunnel_rquotad_port,
          stunnel_socket_options => $stunnel_socket_options,
          stunnel_verify         => $stunnel_verify,
          stunnel_wantedby       => $stunnel_wantedby,
          firewall               => $firewall,
          tcpwrappers            => $tcpwrappers,
        }
      )
    }
  }

  if $firewall  {
    # Open up the firewall for incoming, side-band NFS channels.  Without
    # pre-configuring each NFS server to know all the clients they are
    # communicating with, these channels cannot be carried over stunnel.
    # However, the security risk is minimized, because the side-channels
    # are not used to carry file content.
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
          dports       => [$client_callback_port]
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
      $_rpcbind_port = 111
      $_tcp_status_ports = [
        $_rpcbind_port,
        $client_lockd_port,
        $client_statd_port
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
        $client_lockd_udp_port,
        $client_statd_port
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
