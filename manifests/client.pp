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
  Boolean          $blkmap         = false,  # NFSV4.1 or later
  Simplib::Port    $callback_port  = 876,    # NFSV4.0
  Boolean          $firewall       = $nfs::firewall,
  Boolean          $stunnel        = $nfs::stunnel,
  Integer[0]       $stunnel_verify = 2,
  Boolean          $tcpwrappers    = $nfs::tcpwrappers
) inherits ::nfs {

  assert_private()

  include 'nfs::base_config'
  include 'nfs::base_service'
  include 'nfs::client::config'

  service { 'nfs-client.target':
    ensure     => 'running',
    enable     => true,
    hasrestart => true
  }

  Class['nfs::base_config'] ~> Class['nfs::base_service']
  Class['nfs::base_config'] ~> Service['nfs-client.target']

  Class['nfs::client::config'] ~> Class['nfs::base_service']
  Class['nfs::client::config'] ~> Service['nfs-client.target']

  Class['nfs::base_service'] ~> Service['nfs-client.target']

  if $blkmap {
    service { 'nfs-blkmap.service':
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  }

  if $nfs::kerberos {
    Class['krb5'] ~> Class['nfs::base_service']

    if $nfs::keytab_on_puppet {
      Class['krb5::keytab'] ~> Class['nfs::base_service']
    }
  }
}
