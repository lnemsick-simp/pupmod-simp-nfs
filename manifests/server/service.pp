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

  # nfs-mountd is required for both NFSv3 and NFSv4 and is started
  # when needed, but only has over-the-wire operation in NFSv3
  svckill::ignore { 'nfs-mountd': }

  # required by rpc-rquotad.service and common NFSv3 services
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

  if $::nfs::server::firewall {
    include 'nfs::server::firewall'
  }

  if $::nfs::server::stunnel {
    include 'nfs::server::stunnel'
    if $::nfs::server::firewall {
      Class['nfs::server::firewall'] ~> Class['nfs::server::stunnel']
    }
  }
}
