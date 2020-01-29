#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::service
{
  assert_private()

  service { 'nfs-server.service':
    ensure     => 'running',
    enable     => true,
    # use the less disruptive reload if possible for a restart
    hasrestart => false,
    restart    => 'systemctl reload-or-restart nfs-server.service',
    hasstatus  => true
  }

  if $::nfs::nfsv3 {
    svckill::ignore { 'nfs-mountd': }
  } else {
#FIXME Should we mask nfs-mountd.service?
  }

  ensure_resource(
    'service',
    'rpcbind.service',
    {
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  )

  service { 'rpc-rquotad.service':
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
  }

  if $::nfs::idmapd {
    include 'nfs::idmapd::server'
  }

  if $::nfs::server::stunnel {
    include 'nfs::server::stunnel'
    if $::nfs::server::firewall {
#      Class['nfs::server::stunnel'] ~> Class['nfs::server::firewall']
#or
      Class['nfs::server::stunnel'] -> Class['nfs::server::firewall']
    }
  }

  if $::nfs::server::firewall {
    include 'nfs::server::firewall'
  }
}
