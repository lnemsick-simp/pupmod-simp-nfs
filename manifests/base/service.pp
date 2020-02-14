class nfs::base::service
{
  assert_private()

  if $nfs::nfsv3 {

    # Normally started on the client when a NFS filesystem is mounted,
    # but does no harm to have it running before the mount
    service { 'rpc-statd.service':
      # static service, so can't enable
      ensure     => 'running',
      hasrestart => true
    }

    # This service gets triggered when a client/server reboots, executes,
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

  if $nfs::secure_nfs {
    # static service, so don't attempt to enable
    service { 'rpc-gssd.service':
      ensure     => 'running',
      hasrestart => true
    }

    exec { 'unmask_rpc-gssd.service':
      command => '/usr/bin/systemctl mask rpc-gssd.service',
      onlyif  => '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked',
      notify  => Service['rpc-gssd.service']
    }

    if $nfs::gssd_use_gss_proxy {
      # gssproxy may be being used by other filesystem services and thus
      # managed elsewhere
      $_gssproxy_params = {
        ensure     => 'running',
        enable     => true,
        hasrestart => true
      }
      ensure_resource('service', 'gssproxy.service', $_gssproxy_params)
    }

  } else {
    # service { NAME: enable => mask } does not seem to work in puppet.
    # So, we will enforce masking of the service here.

    service { 'rpc-gssd.service':
      ensure => 'stopped'
    }

    exec { 'mask_rpc-gssd.service':
      command => '/usr/bin/systemctl mask rpc-gssd.service',
      unless  => '/usr/bin/systemctl status rpc-gssd.service | /usr/bin/grep -qw masked',
      require => Service['rpc-gssd.service']
    }

    # do nothing with gssproxy.service, because it could be in use elsewhere
  }
}
