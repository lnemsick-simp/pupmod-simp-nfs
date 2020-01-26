# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::idmapd::server
{
  assert_private()

  include 'nfs::idmapd::config'

  service { 'nfs-idmapd.service':
    ensure     => 'running',
    enable     => true,
    hasrestart => true
  }

  File['/etc/idmapd.conf'] ~> Service['nfs-idmapd.service']
}
