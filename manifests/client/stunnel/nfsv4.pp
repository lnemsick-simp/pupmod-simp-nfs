# Connect to an NFSv4 server over stunnel
#
# No stunnel connections will be made to the local system if possible due to
# the likelihood of a port conflict. If you're connecting to the local system,
# please use a direct connection.
#
# @param name [Simplib::Host::Port]
#   An ``<ip>:<port>`` combination to the remote NFSv4 server
#
#   * The ``port`` must be the port upon which the **local** stunnel should
#     listen for connections from the local system's NFS services.
#
# @param nfs_connect_port
#   The ``stunnel`` remote connection port
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::stunnel::nfsv4 (
  Simplib::Host $nfs_server,
  Simplib::Port $nfsd_accept_port,
  Simplib::Port $nfsd_connect_port,
  Simplib::Port $rquotad_accept_port,
  Simplib::Port $rquotad_connect_port,
  Array[String] $stunnel_socket_options,
  Integer[0]    $stunnel_verify,
  Array[String] $stunnel_wantedby,
  Boolean       $firewall,
  Boolean       $tcpwrappers,
) {
  assert_private()

  # Don't do this if you're running on yourself because, well, it's bad!
  # FIXME verify that the local mount location will work, so these tunnels
  #  aren't really needed
  unless simplib::host_is_me($nfs_server) {
    stunnel::instance { "nfs_${name}_client_nfsd":
      connect          => ["${nfs_server}:${nfsd_connect_port}"],
      accept           => "127.0.0.1:${$nfsd_accept_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }

    stunnel::instance { "nfs_${name}_client_rquotad":
      connect          => ["${nfs_server}:${rquotad_connect_port}"],
      accept           => "127.0.0.1:${nfs::rquotad_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }
  }
}
