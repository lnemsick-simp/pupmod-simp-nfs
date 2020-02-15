class nfs::server::stunnel::nfsv4 {

  assert_private()

  $_nfsv4_services = [
    'nfs-server.service',
    'nfs-idmapd.service',
    'rpc-rquotad.service',
    'rpcbind.service',
    # secure NFS
    'rpc-gssd.service',
    'gssproxy.service',
  ]

  $_stunnel_wantedby = unique( $_nfsv4_services + $nfs::server::stunnel::stunnel_wantedby )
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

  #FIXME this is the opposite of the systemd_wantedby
#  Service['nfs-server.service'] -> Stunnel::Instance['nfs']
}
