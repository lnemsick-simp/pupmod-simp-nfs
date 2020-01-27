# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::tcpwrappers
{
  assert_private()

  include 'tcpwrappers'

  # On EL7, the following NFS-related executables are dynamically linked to
  # libwrap:
  # * rpc.rquotad; man page says TCP wrappers service name 'rquotad'
  # * rpc.statd; man pages says TCP wrappers under daemon name 'statd'
  # * rpc.mountd; man page says TCP wrappers under daemon name 'mountd'
  # * exportfs; not a daemon so not appropriate
  # * rpcbind
  #

  $_allow_common = [
    'rpcbind',
    'rquotad'
  ]

  if $::nfs::nfsv3 {
    $_allow = [
    'lockd',
    'mountd',
    'statd'
    ] + $_allow_common
  } else {
    $_allow = $_allow_common
  }

  tcpwrappers::allow { $_allow:
    pattern => $trusted_nets
  }

  if $::nfs::server::stunnel {
    # stunnel also uses TCP wrappers with a service name that matches the tunnel's
    # service name. Here, we all ALL not just the trusted nets, because there
    # seems to be a bug that doesn't allow trusted nets.
    # TODO verify this is still true
    # tcpwrappers::allow { 'nfs': pattern => $::nfs::server::stunnel::trusted_nets }
    tcpwrappers::allow { 'nfs': pattern => 'ALL' }
  }
}
