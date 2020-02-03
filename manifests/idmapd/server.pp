# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::idmapd::server
{
  assert_private()
  if $::nfs::idmapd {
    include 'nfs::idmapd::config'

    service { 'nfs-idmapd.service':
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }

    Class['nfs::idmap::config'] ~> Service['nfs-idmapd.service']

    # Service will be masked if previous config had disallowed idmapd
    exec { 'unmask_nfs-idmapd.service':
      command => '/usr/bin/systemctl unmask nfs-idmpad.service',
      onlyif  => '/usr/bin/systemctl status nfs-idmpad.service | /usr/bin/grep -qw masked',
      notify  => Service['nfs-ipmapd.service']
    }
  } else {
    # service { NAME: enable => mask } does not seem to work in puppet.
    # So, we will enforce masking of the service here.

    service { 'nfs-idmapd.service':
      ensure => 'stopped'
    }

    exec { 'mask_nfs-idmapd.service':
      command => '/usr/bin/systemctl mask nfs-idmapd.service',
      unless  => '/usr/bin/systemctl status nfs-idmapd.service | /usr/bin/grep -qw masked',
      require => Service['nfs-idmapd.service']
    }
  }
}
