# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Connect to an NFSv3 server over stunnel
#
# It is **highly** recommended that you use Kerberos and NFSv4 in all cases.
# This is here in case this is not feasible.
#
# @param nfs_server
#   The host to which you wish to connect
#
# @param nfs_accept_port
#   The ``stunnel`` local accept port
#
# @param nfs_connect_port
#   The ``stunnel`` remote connection port
#
# @param portmapper_accept_port
#   The ``portmapper`` local accept port
#
# @param portmapper_connect_port
#   The ``portmapper`` remote connection port
#
# @param rquotad_connect_port
#   The ``rquotad`` remote connection port
#
# @param lockd_connect_port
#   The ``lockd`` remote connection port
#
# @param mountd_connect_port
#   The ``mountd`` remote connection port
#
# @param statd_connect_port
#   The ``statd`` remote connection port
#
# @param stunnel_verify
#   What level to verify the TLS connection via stunnel
#
#   * See ``stunnel::instance::verify`` for details
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::stunnel::nfsv3 (
  Simplib::Host $nfs_server,
  Simplib::Port $lockd_accept_port,
  Simplib::Port $lockd_connect_port,
  Simplib::Port $nfsd_accept_port,
  Simplib::Port $nfsd_connect_port,
  Simplib::Port $mountd_accept_port,
  Simplib::Port $mountd_connect_port,
  Simplib::Port $rquotad_accept_port,
  Simplib::Port $rquotad_connect_port,
  Simplib::Port $statd_accept_port,
  Simplib::Port $statd_connect_port,
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
    stunnel::instance { 'nfs_${name}_client_nfsd':
      connect          => ["${nfs_server}:${nfsd_connect_port}"],
      accept           => "127.0.0.1:${nfsd_accept_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,

      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_${name}_client_rquotad':
      connect          => ["${nfs_server}:${rquotad_connect_port}"],
      accept           => "127.0.0.1:${::nfs::rquotad_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_${name}_client_lockd':
      connect          => ["${nfs_server}:${lockd_connect_port}"],
      accept           => "127.0.0.1:${nfs::lockd_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_${name}_client_mountd':
      connect          => ["${nfs_server}:${mountd_connect_port}"],
      accept           => "127.0.0.1:${nfs::mountd_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }

    stunnel::instance { 'nfs_${name}_client_statd':
      connect          => ["${nfs_server}:${statd_connect_port}"],
      accept           => "127.0.0.1:${nfs::statd_port}",
      verify           => $stunnel_verify,
      socket_options   => $stunnel_socket_options,
      systemd_wantedby => $stunnel_wantedby,
      firewall         => $firewall,
      tcpwrappers      => $tcpwrappers,
      tag              => ['nfs']
    }
  }
}
