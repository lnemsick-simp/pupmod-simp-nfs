#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::service
{
  assert_private()

  service { 'nfs-server.service':
    ensure     => 'running',
    enable     => true,
    # To ensure we pick up config changes, restart nfs-utils and nfs-server
    # at the same time. Serially restarting the services individually does
    # not reliably work.
    hasrestart => false,
    restart    => 'systemctl restart nfs-utils.service nfs-server.service',
  }

  # nfs-mountd is required for both NFSv3 and NFSv4, is started when needed,
  # and only has over-the-wire operation in NFSv3
  svckill::ignore { 'nfs-mountd': }

  # Required by rpc-rquotad.service, but, since could be required
  # by non-NFS-related daemons, could managed by elsewhere
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

}
