class nfs::service::nfsv3_base
{
  assert_private()

  if $::nfs::nfsv3 {
    # NFS isn't the only RPC user...
    ensure_resource(
      'service',
      'rpcbind.service',
      {
        ensure     => 'running',
        enable     => true,
        hasrestart => true
      }
    )

    service { 'rpc-statd.service':
      # static service, so can't enable
      ensure     => 'running',
      hasrestart => true
    }

    # This service gets triggered when the server reboots, executes,
    # and then exits.  Doesn't make sense to ensure running, but in
    # the extremely unlikely chance svckill is running when the
    # service runs, make sure svckill leaves it alone.
    svckill::ignore{ 'rpc-statd-notify.service': }

    # Service will be masked if previous config had disallowed NFSv3.
    exec { 'unmask_rpc-statd.service':
      command => '/usr/bin/systemctl unmask rpc-statd.service',
      onlyif  => '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked',
      notify  => Service['rpc-statd.service']
    }

  } else {
    # service { NAME: enable => mask } does not seem to work in puppet.
    # So, we will enforce masking of the service here.

    service { 'rpc-statd.service':
      ensure => 'stopped'
    }

    exec { 'mask_rpc-statd.service':
      command => '/usr/bin/systemctl mask rpc-statd.service',
      unless  => '/usr/bin/systemctl status rpc-statd.service | /usr/bin/grep -qw masked',
      require => Service['rpc-statd.service']
    }
  }
}
