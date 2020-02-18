class nfs::server::stunnel::nfsv4 {

  assert_private()

  $_accept_addr = $nfs::server::stunnel_accept_address

  stunnel::instance { 'nfsd':
    client           => false,
    trusted_nets     => $nfs::server::trusted_nets,
    connect          => [$nfs::nfsd_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel_nfsd_accept_port}",
    verify           => $nfs::server::stunnel_verify,
    socket_options   => $nfs::server::stunnel_socket_options,
    systemd_wantedby => $nfs::server::stunnel_wantedby,
    firewall         => $nfs::firewall,
    tcpwrappers      => $nfs::tcpwrappers,
    tag              => ['nfs']
  }

  stunnel::instance { 'rquotad':
    client           => false,
    trusted_nets     => $nfs::server::trusted_nets,
    connect          => [$nfs::rquotad_port],
    accept           => "${_accept_addr}:${nfs::server::stunnel_rquotad_accept_port}",
    verify           => $nfs::server::stunnel_verify,
    socket_options   => $nfs::server::stunnel_socket_options,
    systemd_wantedby => $nfs::server::stunnel_wantedby,
    firewall         => $nfs::firewall,
    tcpwrappers      => $nfs::tcpwrappers,
    tag              => ['nfs']
  }
}
