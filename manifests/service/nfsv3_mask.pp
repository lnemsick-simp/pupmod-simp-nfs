class nfs::service::nfsv3_mask
{
  assert_private()

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

# FIXME
# Not necessary.  Not a running daemon.  Just gets triggered when needed
#  service { 'rpc-statd-notify.service':
#    ensure => 'stopped'
#  }

  exec { 'mask_rpc-statd-notify.service':
    command => '/usr/bin/systemctl mask rpc-statd-notify.service',
    unless  => '/usr/bin/systemctl status rpc-statd-notify.service | /usr/bin/grep -qw masked',
#FIXME
#    require => Service['rpc-statd-notify.service']
  }

}
