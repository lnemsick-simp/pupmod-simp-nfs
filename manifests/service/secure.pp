class nfs::service::secure
{
  assert_private()

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

  if $::nfs::gssd_use_gss_proxy {
    # gssproxy may be being used by other filesystem services and thus
    # managed elsewhere
    $_gssproxy_params = {
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
    ensure_resource('service', 'gssproxy.service', $_gssproxy_params)
  }
}
