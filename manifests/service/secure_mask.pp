class nfs::service::secure_mask
{
  assert_private()

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
