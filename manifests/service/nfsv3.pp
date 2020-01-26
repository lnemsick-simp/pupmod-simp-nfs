class nfs::nfsv3_base_services
{
  assert_private()

  service { 'rpc-statd.service':
    # static service, so can't enable
    ensure  => 'running',
    hasrestart => true
  }

  service { 'rpc-statd-notify.service ':
    # static service, so can't enable
    ensure  => 'running',
    hasrestart => true
  }
}
