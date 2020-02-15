class nfs::server::stunnel::nfsv3and4 {

  assert_private()

  $_nfs_services = [
    'nfs-server.service',       # NFSv3+NFSv4
    'nfs-mountd.service',       # NFSv3
    'rpc-statd.service',        # NFSv3
    'rpc-statd-notify.service', # NFSv3
    'nfs-idmapd.service',       # NFSv4
    'rpc-rquotad.service',      # NFSv3+NFSv4
    'rpcbind.service',          # NFSv3+NFSv4
    'rpc-gssd.service',         # secure NFS
    'gssproxy.service',         # secure NFS
  ]

  $_stunnel_wantedby = unique( $_nfs_services + $nfs::server::stunnel::stunnel_wantedby )
  $_accept_addr = $nfs::server::stunnel::nfs_accept_address

  stunnel::instance { 'nfs':
    client           => false,
    trusted_nets     => $nfs::server::stunnel::trusted_nets,
    connect          => [$nfs::nfsd_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel::nfs_accept_port}",
    verify           => $nfs::server::stunnel::verify,
    socket_options   => $nfs::_stunnel_socket_options,
    systemd_wantedby => $_stunnel_wantedby,
    firewall         => $nfs::server::stunnel::firewall,
    tcpwrappers      => $nfs::server::stunnel::tcpwrappers,
    tag              => ['nfs']
  }

  stunnel::instance { 'nlockmgr':
    client           => false,
    trusted_nets     => $nfs::server::stunnel::trusted_nets,
    connect          => [$nfs::lockd_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel::nlockmgr_accept_port}",
    verify           => $nfs::server::stunnel::verify,
    socket_options   => $nfs::_stunnel_socket_options,
    systemd_wantedby => $_stunnel_wantedby,
    firewall         => $nfs::server::stunnel::firewall,
    tcpwrappers      => $nfs::server::stunnel::tcpwrappers,
    tag              => ['nfs']
  }

  stunnel::instance { 'mountd':
    client           => false,
    trusted_nets     => $nfs::server::stunnel::trusted_nets,
    connect          => [$nfs::mountd_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel::mountd_accept_port}",
    verify           => $nfs::server::stunnel::verify,
    socket_options   => $nfs::_stunnel_socket_options,
    systemd_wantedby => $_stunnel_wantedby,
    firewall         => $nfs::server::stunnel::firewall,
    tcpwrappers      => $nfs::server::stunnel::tcpwrappers,
    tag              => ['nfs']
  }

  stunnel::instance { 'status':
    client           => false,
    trusted_nets     => $nfs::server::stunnel::trusted_nets,
    connect          => [$nfs::statd_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel::status_accept_port}",
    verify           => $nfs::server::stunnel::verify,
    socket_options   => $nfs::_stunnel_socket_options,
    systemd_wantedby => $_stunnel_wantedby,
    firewall         => $nfs::server::stunnel::firewall,
    tcpwrappers      => $nfs::server::stunnel::tcpwrappers,
    tag              => ['nfs']
  }

  #FIXME this is the opposite of the systemd_wantedby
#  Service['nfs-server.service'] -> Stunnel::Instance['nfs']
#  Service['nfs-server.service'] -> Stunnel::Instance['nlockmgr']
#  Service['nfs-server.service'] -> Stunnel::Instance['mountd']
#  Service['nfs-server.service'] -> Stunnel::Instance['status']
}
