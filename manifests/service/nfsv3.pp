class nfs::service::nfsv3
{
  assert_private()

  ensure_resource(
    'service',
    'rpcbind.service',
    {
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  )

  exec { 'unmask_rpc-statd.service':
    command => '/usr/bin/systemctl unmask rpc-statd.service',
    onlyif  => '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked',
    notify  => Service['rpc-statd.service']
  }

  service { 'rpc-statd.service':
    # static service, so can't enable
    ensure     => 'running',
    hasrestart => true
  }

  exec { 'unmask_rpc-statd-notify.service':
    command => '/usr/bin/systemctl unmask rpc-statd-notify.service',
    onlyif  => '/usr/bin/systemctl status rpc-statd-notify.service | /usr/bin/grep -qw masked',
#FIXME
#    notify  => Service['rpc-statd-notify.service']
  }

# FIXME  This isn't necessary.  Gets triggered when needed.
#  service { 'rpc-statd-notify.service':
#    # static service, so can't enable
#    ensure     => 'running',
#    hasrestart => true
#  }
}
