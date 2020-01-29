# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::idmapd::server
{
  include 'nfs::idmapd::config'

  service { 'nfs-idmapd.service':
    ensure     => 'running',
    enable     => true,
    hasrestart => true
  }

  Class['nfs::idmap::config'] ~> Service['nfs-idmapd.service']
}
