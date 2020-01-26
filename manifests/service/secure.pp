class nfs::service::secure
{
  assert_private()

  # static service, so don't attempt to enable
  service { 'rpc-gssd.service':
    ensure     => 'running',
    hasrestart => true
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
