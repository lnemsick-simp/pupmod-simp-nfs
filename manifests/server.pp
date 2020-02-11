# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Configure a NFS server with a default configuration that nails up the ports
# so that you can pass them through ``iptables``.
#
# This defaults to ``NFSv4``.
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to ``any`` or ``ALL`` to allow the world
#
# @param nfsv3
#   Serve out ``NFSv3`` shares
#
#
# @param lockd_arg
#   Options that should be passed to ``lockd`` at start time
#
# @param nfsd_module
#   If set to ``noload`` will prevent the ``nfsd`` kernel module from being
#   pre-loaded
#
#   * **NOTE:** if this is set to _anything_, the template will say ``noload``
#
# @param rpcmountdopts
#   An arbitrary string of options to pass to ``mountd`` at start time
#
# @param statdarg
#   An arbitrary string of options to pass to ``statd`` at start time
#
# @param statd_ha_callout
#   The path to an application that should be used for ``statd`` HA
#
# @param rpcidmapdargs
#   Arbibrary arguments to pass to ``idmapd`` at start time
#
# @param rpcgssdargs
#   Arbitrary arguments to pass to ``gssd`` at start time
#
# @param rpcsvcgssdargs
#   Arbitrary arguments to pass to ``svcgssd`` at start time
#
# @param sunrpc_udp_slot_table_entries
#
#   Set the default UDP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @param sunrpc_tcp_slot_table_entries
#
#   Set the default TCP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @note Due to a bug in EL, ``$mountd_nfs_v1`` must be set to ``yes`` to
#   properly unmount
#
# @note The ``rpcbind`` port and the ``rpc.quotad`` ports are open to the
#   trusted networks so that the ``quota`` command works on the clients
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param stunnel Use the SIMP ``stunnel`` module to manage stunnel
#
#   * This will configure the NFS server to only use TCP communication
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server (
#FIXME only have attributes that really need to be here
  Boolean          $nfsd_vers4                    = true,
  Boolean          $nfsd_vers4_0                  = true,
  Boolean          $nfsd_vers4_1                  = true,
  Boolean          $nfsd_vers4_2                  = true,
  Optional[String] $custom_rpcrquotad_opts        = undef,
  Integer[1]       $sunrpc_udp_slot_table_entries = 128,
  Integer[1]       $sunrpc_tcp_slot_table_entries = 128,
  Boolean          $firewall                      = $nfs::firewall,
  Boolean          $stunnel                       = $nfs::stunnel,
  Boolean          $tcpwrappers                   = $nfs::tcpwrappers,
  Simplib::Netlist $trusted_nets                  = $nfs::trusted_nets
) inherits ::nfs {

  assert_private()

  include 'nfs::base_config'
  include 'nfs::base_service'
  include 'nfs::server::config'
  include 'nfs::server::service'

  Class['nfs::base_config'] ~> Class['nfs::base_service']
  Class['nfs::base_config'] ~> Class['nfs::server::service']

  Class['nfs::server::config'] ~> Class['nfs::base_service']
  Class['nfs::server::config'] ~> Class['nfs::server::service']

  Class['nfs::base_service'] ~> Class['nfs::server::service']

  include 'nfs::idmapd::server'

  if $nfs::server::stunnel {
    include 'nfs::server::stunnel'
  }

  if $nfs::server::firewall {
    include 'nfs::server::firewall'

    if $nfs::server::stunnel {
      Class['nfs::server::firewall'] ~> Class['nfs::server::stunnel']
    }
  }

   #FIXME Should this be nfs::server::kerberos ?
   #FIXME Does the nfs::server::servic really need to be restarted or is
   #      restarting the rpc-gssd and gssproxy services in nfs::base_service
   #      sufficient?
  if $nfs::kerberos {
    Class['krb5'] ~> Class['nfs::base_service']
    Class['krb5'] ~> Class['nfs::server::service']

    if $nfs::keytab_on_puppet {
      Class['krb5::keytab'] ~> Class['nfs::base_service']
      Class['krb5::keytab'] ~> Class['nfs::server::service']
    }
  }
}
