class nfs::nfsv3_base_services {

  service { 'rpc-statd.service':
    ensure     => 'running'
  }
}
