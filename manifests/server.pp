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
# @param stunnel_accept_address
#   The address upon which the NFS server will listen
#
#   * You should be set this to ``0.0.0.0`` for all interfaces
#
# @param stunnel_nfsd_accept_port
#   Stunnel listening port to be forwarded to the nfsd listening port,
#   ``nfs::nfsd_port``
#
# @param stunnel_lockd_accept_port
#   Stunnel listening port to be forwarded to the NFSv3 lockd listening port,
#   ``nfs::lockd_port``
#
# @param stunnel_mountd_accept_port
#   Stunnel listening port to be forwarded to the NFSv3 nfs-mountd service,
#   ``nfs::mountd_port``
#
# @param stunnel_statd_accept_port
#   Stunnel listening port to be forwarded to the NFSv3 rpc-statd service
#   listening port, ``nfs::statd_port``
#
# @param stunnel_verify
#   The verification level that should be done on the clients
#
#   * See ``stunnel::instance::verify`` for details
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server (
  Boolean          $nfsd_vers4                    = true,
  Boolean          $nfsd_vers4_0                  = true,
  Boolean          $nfsd_vers4_1                  = true,
  Boolean          $nfsd_vers4_2                  = true,
  Optional[String] $custom_rpcrquotad_opts        = undef,
  Integer[1]       $sunrpc_udp_slot_table_entries = 128,
  Integer[1]       $sunrpc_tcp_slot_table_entries = 128,
  Boolean          $stunnel                       = $nfs::stunnel,
  Simplib::IP      $stunnel_accept_address        = '0.0.0.0',
  Simplib::Port    $stunnel_lockd_accept_port     = $nfs::stunnel_lockd_port,
  Simplib::Port    $stunnel_mountd_accept_port    = $nfs::stunnel_mountd_port,
  Simplib::Port    $stunnel_nfsd_accept_port      = $nfs::stunnel_nfsd_port,
  Simplib::Port    $stunnel_rquotad_accept_port   = $nfs::stunnel_rquotad_port,
  Simplib::Port    $stunnel_statd_accept_port     = $nfs::stunnel_statd_port,
  Array[String]    $stunnel_socket_options        = $nfs::stunnel_socket_options,
  Integer          $stunnel_verify                = $nfs::stunnel_verify,
  Array[String]    $stunnel_wantedby              = [
    'gssproxy.service',         # secure NFS
    'nfs-idmapd.service',       # NFSv4
    'nfs-mountd.service',       # NFSv3
    'nfs-server.service',       # NFSv3+NFSv4
    'rpc-gssd.service',         # secure NFS
    'rpc-rquotad.service',      # NFSv3+NFSv4
    'rpc-statd.service',        # NFSv3
    'rpc-statd-notify.service', # NFSv3
    'rpcbind.service',          # NFSv3+NFSv4
  ],
  Boolean          $tcpwrappers                   = $nfs::tcpwrappers,
  Simplib::Netlist $trusted_nets                  = $nfs::trusted_nets
) inherits ::nfs {

  assert_private()

  include 'nfs::base::config'
  include 'nfs::base::service'
  include 'nfs::server::config'
  include 'nfs::server::service'

  Class['nfs::base::config'] ~> Class['nfs::base::service']
  Class['nfs::server::config'] ~> Class['nfs::server::service']
  Class['nfs::base::service'] ~> Class['nfs::server::service']

  include 'nfs::idmapd::server'

  if $nfs::server::stunnel {
    include 'nfs::server::stunnel'
    Class['nfs::server::stunnel'] ~> Class['nfs::server::service']
  }

  if $nfs::firewall {
    include 'nfs::server::firewall'
  }

  if $nfs::kerberos {
    include 'krb5'

    Class['krb5'] ~> Class['nfs::server::service']

    if $nfs::keytab_on_puppet {
      include 'krb5::keytab'

      Class['krb5::keytab'] ~> Class['nfs::server::service']
    }
  }
}
