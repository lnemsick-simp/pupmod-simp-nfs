# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::tcpwrappers
{
  assert_private()

  if (versioncmp($facts['os']['release']['major'], '8') < 0) {
    # tcpwrappers was dropped in EL8
    include 'tcpwrappers'

    # On EL7, the following NFS-server-related executables are dynamically
    # linked to libwrap:
    # * rpc.rquotad; man page says TCP wrappers service name 'rquotad'
    # * rpc.statd; man page says TCP wrappers under daemon name 'statd'
    # * rpc.mountd; man page says TCP wrappers under daemon name 'mountd'
    # * exportfs; not a daemon so not appropriate
    # * rpcbind

    $_allow_options = { pattern => $nfs::trusted_nets }

    if $nfs::nfsv3 {
      # Resource in common with nfs::client, which may be on this node.
      ensure_resource('tcpwrappers::allow', 'statd', $_allow_options)

      $_allow = [ 'mountd', 'rquotad' ]
    } else {
      $_allow = ['rquotad']
    }

    # Resource in common with nfs::client, which may be on this node.
    ensure_resource('tcpwrappers::allow', 'rpcbind', $_allow_options)

    tcpwrappers::allow { $_allow:
      pattern => $nfs::server::trusted_nets
    }

    if $nfs::server::stunnel {
      # stunnel also uses TCP wrappers with a service name that matches the tunnel's
      # service name. Here, we allow ALL not just the trusted nets, because there
      # seems to be a bug that doesn't allow trusted nets.
      # TODO verify this is still true
      # tcpwrappers::allow { 'nfs': pattern => $nfs::server::stunnel::trusted_nets }
      tcpwrappers::allow { 'nfs': pattern => 'ALL' }

      #FIXME What about NFSv3 stunnels?  all tagged with 'nfs'...Is this the
      # stunnel service name?
    }
  }
}
