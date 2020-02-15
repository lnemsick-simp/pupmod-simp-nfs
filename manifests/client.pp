# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Set up the iptables hooks and the sysctl settings that are required for NFS
# to function properly on a client system.
#
# If using the ``nfs::client::stunnel::connect`` define, this will be
# automatically called for you.
#
# @param callback_port
#   The port used by the server to recall delegation of responsibilities to a
#   client in NFSv4.0.  Beginning with NFSv4.1, a separate callback side channel
#   is not required.
#
# @param stunnel
#   Enable ``stunnel`` connections for this system
#
#   * Will *attempt* to determine if the server is trying to connect to itself
#
#   * If connecting to itself, will not use stunnel, otherwise will use stunnel
#
#   * If you are using host aliases for your NFS server names, this check
#     may fail and you may need to disable ``$stunnel`` explicitly
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
#   * See ``stunnel::connection::verify`` for details
#
# @param firewall
#   Use the SIMP IPTables module to manipulate the firewall settings
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client (
  Boolean          $blkmap           = false,  # NFSV4.1 or later
  Simplib::Port    $callback_port    = 876,    # NFSV4.0
  Boolean          $firewall         = $nfs::firewall,
  Boolean          $stunnel          = $nfs::stunnel,
  Integer[0]       $stunnel_verify   = 2,
  Array[String]    $stunnel_wantedby = ['remote-fs-pre.target'],
  Boolean          $tcpwrappers      = $nfs::tcpwrappers
) inherits ::nfs {

  assert_private()

  include 'nfs::base::config'
  include 'nfs::base::service'
  include 'nfs::client::config'
  include 'nfs::client::service'

  Class['nfs::base::config'] ~> Class['nfs::base::service']
  Class['nfs::client::config'] ~> Class['nfs::client::service']
  Class['nfs::base::service'] ~> Class['nfs::client::service']

  if $nfs::kerberos {
    include 'krb5'

    # make sure gssproxy service is restarted if we are using it
    # FIXME replace with notify of nfs::client::service when gssproxy
    # is part of nfs-utils
    Class['krb5'] ~> Class['nfs::base::service']

    if $nfs::keytab_on_puppet {
      include 'krb5::keytab'
      # make sure gssproxy service is restarted if we are using it
      # FIXME replace with notify of nfs::client::service when gssproxy
      # is part of nfs-utils
      Class['krb5::keytab'] ~> Class['nfs::base::service']
    }
  }
}
