class nfs::nfsv3_base_services
{
  assert_private()

  if $nfsv3 {
    service { 'rpc-statd.service':
      ensure   => 'running',
      restart => true
    }

    service { 'rpc-statd-notify.service ':
      ensure  => 'running',
      restart => true
    }
  else {
    service { 'rpc-statd.service':
      ensure => 'mask'
    }

    service { 'rpc-statd-notify.service':
      ensure => 'mask'
  }
}
