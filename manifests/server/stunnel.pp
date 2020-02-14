# Configures a server for NFS over stunnel
#
# Known to work with ``NFSv3`` and ``NFSv4``.
#
# @param version
#   The version of NFS to use
#
# @param verify
#   The verification level that should be done on the clients
#
#   * See ``stunnel::instance::verify`` for details
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# @param nfs_accept_address
#   The address upon which the NFS server will listen
#
#   * You should be set this to ``0.0.0.0`` for all interfaces
#
# @param nfs_accept_port
#   Stunnel listening port mapped to the nfsd listening port
#
# @param portmapper_accept_port
#   Stunnel listening port mapped to the rpcbind service listening port
#
# @param rquotad_accept_port
#   Stunnel listening port mapped to the rpc-rquotad service listening port
#
# @param nlockmgr_accept_port
#   Stunnel listening port mapped to the NFSv3 lockd listening port
#
# @param mountd_accept_port
#   Stunnel listening port mapped to the NFSv3 nfs-mountd service listening port
#
# @param status_accept_port
#   Stunnel listening port mapped to the NFSv3 rpc-statd service listening port
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::stunnel (
  Integer[3,4]     $version                = 4,
  Integer          $verify                 = 2,
  Simplib::Netlist $trusted_nets           = $nfs::server::trusted_nets,
  Simplib::IP      $nfs_accept_address     = '0.0.0.0',
  Simplib::Port    $nfs_accept_port        = 20490,
  Simplib::Port    $portmapper_accept_port = 1110,
  Simplib::Port    $rquotad_accept_port    = 8750,
  Simplib::Port    $nlockmgr_accept_port   = 32804,
  Simplib::Port    $mountd_accept_port     = 8920,
  Simplib::Port    $status_accept_port     = 6620,
  Array[String]    $stunnel_wantedby       = $nfs::stunnel_wantedby
) {
assert_private()
  $_common_services = [
    'nfs-server.service',
    'nfs-idmapd.service',
    'rpc-rquotad.service',
    'rpcbind.service',
    # secure NFS
    'rpc-gssd.service',
    'gssproxy.service',
  ]

  if $version == 4 {
    $_stunnel_wantedby = unique( $_common_services + $stunnel_wantedby )
    stunnel::instance { 'nfs':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::nfsd_port],
      accept           => "${nfs_accept_address}:${nfs_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    stunnel::instance { 'portmapper':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [111],
      accept           => "${nfs_accept_address}:${portmapper_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'rquotad':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::rquotad_port],
      accept           => "${nfs_accept_address}:${rquotad_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    $stunnel_port_override = [
      $nfs_accept_port,
      $portmapper_accept_port,
      $rquotad_accept_port,
    ]

    #FIXME need other part of tunnel for callback port

    #FIXME this is the opposite of the systemd_wantedby
    Service['nfs-server.service'] -> Stunnel::Instance['nfs']
    Service['nfs-server.service'] -> Stunnel::Instance['portmapper']
    Service['nfs-server.service'] -> Stunnel::Instance['rquotad']
  }
  else {
    $_nfsv3_services = $_common_services + [
      'nfs-mountd.service',
      'rpc-statd.service',
      'rpc-statd-notify.service',
    ]
    $_stunnel_wantedby = unique( $_nfsv3_services + $stunnel_wantedby )
    stunnel::instance { 'nfs':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::nfsd_port],
      accept           => "${nfs_accept_address}:${nfs_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'portmapper':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [111],
      accept           => "${nfs_accept_address}:${portmapper_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'rquotad':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::rquotad_port],
      accept           => "${nfs_accept_address}:${rquotad_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'nlockmgr':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::lockd_port],
      accept           => "${nfs_accept_address}:${nlockmgr_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'mountd':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::mountd_port],
      accept           => "${nfs_accept_address}:${mountd_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }
    stunnel::instance { 'status':
      client           => false,
      trusted_nets     => $trusted_nets,
      connect          => [$nfs::statd_port],
      accept           => "${nfs_accept_address}:${status_accept_port}",
      verify           => $verify,
      socket_options   => $nfs::_stunnel_socket_options,
      systemd_wantedby => $_stunnel_wantedby,
      tag              => ['nfs']
    }

    #FIXME this is the opposite of the systemd_wantedby
    Service['nfs-server.service'] -> Stunnel::Instance['nfs']
    Service['nfs-server.service'] -> Stunnel::Instance['portmapper']
    Service['nfs-server.service'] -> Stunnel::Instance['rquotad']
    Service['nfs-server.service'] -> Stunnel::Instance['nlockmgr']
    Service['nfs-server.service'] -> Stunnel::Instance['mountd']
    Service['nfs-server.service'] -> Stunnel::Instance['status']

    $stunnel_port_override = [
      $nfs_accept_port,
      $portmapper_accept_port,
      $rquotad_accept_port,
      $nlockmgr_accept_port,
      $mountd_accept_port,
      $status_accept_port
    ]
  }
}
