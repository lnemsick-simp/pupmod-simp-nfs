# Provides the base configuration and services for an NFS server and/or client.
#
# @param is_server
#   Explicitly state that this system should be an NFS server
#
#   * Further configuration can be made via the ``nfs::server`` classes
#
# @param is_client
#   Explicitly state that this system should be an NFS client
#
#   * Further configuration can be be made via the ```nfs::client`` classes
#
# @param nfsv3
#   Allow use of NFSv3.  When false, only NFSv4 will be supported.
#
# @param rquotad_port
#   The port upon which ``rquotad`` on the NFS server should listen
#
#   * The ``rquotad`` service port reported by ``rpcinfo``
#
# @param lockd_port
#   The TCP port upon which ``lockd`` should listen on both the
#   server and the client (NFSv3)
#
#   * The ``nlockmgr`` service TCP port reported by ``rpcinfo``
#
# @param lockd_udpport
#   The UDP port upon which ``lockd`` should listen on both the
#   server and the client (NFSv3)
#
#   * The ``nlockmgr`` service UDP port reported by ``rpcinfo``
#
# @param mountd_port
#   The port upon which ``mountd`` should listen on the server (NFSv3)
#
#   * The ``mountd`` service port reported by ``rpcinfo``
#
# @param statd_port
#   The port upon which ``statd`` should listen on both the server
#   and the client (NFSv3)
#
#   * The ``status`` service port reported by ``rpcinfo``
#
# @param statd_outgoing_port
#   The port that ``statd`` will use when connecting to NFSv3 peers
#
# @param secure_nfs
#   Enable secure NFS mounts
#
# @param ensure_latest_lvm2
#   See ``nfs::lvm2`` for further description
#
# @param kerberos
#   Use the SIMP ``krb5`` module for Kerberos support
#
#   * You may need to set variables in ``krb5::config`` via Hiera or your ENC
#     if you do not like the defaults.
#
# @param keytab_on_puppet
#   Whether the NFS server will pull its keytab directly from the Puppet server
#
#   * Only applicable if ``$kerberos` is ``true.
#   * If ``false``, you will need to ensure the appropriate services are restarted
#     and cached credentials are destroyed (e.g., gssproxy cache), when the keytab
#     is changed.
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @param stunnel
#   Wrap ``stunnel`` around critical NFS connections
#
#   * This is intended for environments without a working Kerberos setup
#     and may cause issues when used with Kerberos.
#   * Use of Kerberos is preferred.
#   * This will configure the NFS server to only use TCP communication
#   * The following connections will not be secured, due to stunnel
#     limitations
#
#     - Connections to the rbcbind service
#     - Connections to the rpc-rquotad service
#     - The NFSv4.0 client callback side channel used in NFS delegations.
#     - Client NSM (network status manager) messages which are exclusively
#       sent over UDP.
#
# @param stunnel_tcp_nodelay
#   Enable TCP_NODELAY for all stunnel connections
#
# @param stunnel_socket_options
#   Additional socket options to set for all stunnel connections
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs (
  Boolean               $is_server                     = false,
  Boolean               $is_client                     = true,
  Boolean               $nfsv3                         = false,
  Boolean               $gssd_avoid_dns                = true, # false is considered a security hole
  Boolean               $gssd_limit_to_legacy_enctypes = false, # do not want old ciphers
  Boolean               $gssd_use_gss_proxy           = true,
  Simplib::Port         $lockd_port_client            = 32802,
  Simplib::Port         $lockd_port_server            = 32803,
  Simplib::Port         $lockd_udp_port_server        = 32768,
  Simplib::Port         $lockd_udp_port_client        = 32769,
  Simplib::Port         $lockd_port                   = $is_server ? { 'true' => $lockd_port_server, default => $lockd_port_client},
  Simplib::Port         $lockd_udp_port               = $is_server ? { 'true' => $lockd_udp_port_server, default => $lockd_udp_port_client},
  Simplib::Port         $mountd_port                  = 20048,
  Simplib::Port         $nfsd_port                    = 2049,
  Simplib::Port         $rquotad_port                 = 875,
  Simplib::Port         $sm_notify_outgoing_port      = 2021,
  Simplib::Port         $statd_port_client            = 661,
  Simplib::Port         $statd_port_server            = 662,
  Simplib::Port         $statd_port                   = $is_server ? { 'true' => $statd_port_server, default => $statd_port_client},
  Simplib::Port         $statd_outgoing_port          = 2020,
  Nfs::NfsConfHash      $custom_nfs_conf_opts         = {},
  Nfs::LegacyDaemonArgs $custom_daemon_args           = {},  # only applies to EL7
  Boolean               $idmapd                       = false, #whether to use idmapd/nfsidmap
  Boolean               $secure_nfs                   = false,
  Boolean               $ensure_latest_lvm2           = true,
  Boolean               $kerberos                     = simplib::lookup('simp_options::kerberos', { 'default_value' => false }),
  Boolean               $keytab_on_puppet             = simplib::lookup('simp_options::kerberos', { 'default_value' => true}),
  Boolean               $firewall                     = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
  Boolean               $stunnel                      = simplib::lookup('simp_options::stunnel', { 'default_value' => false }),
  Simplib::Port         $stunnel_lockd_port           = 32804,
  Simplib::Port         $stunnel_mountd_port          = 8920,
  Simplib::Port         $stunnel_nfsd_port            = 20490,
  Simplib::Port         $stunnel_rquotad_port         = 8750,
  Simplib::Port         $stunnel_statd_port           = 6620,
  Array[String]         $stunnel_socket_options       = ['l:TCP_NODELAY=1','r:TCP_NODELAY=1'],
  Integer               $stunnel_verify               = 2,
  Boolean               $tcpwrappers                  = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false }),
  Simplib::Netlist      $trusted_nets                 = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] })
) {

  simplib::assert_metadata($module_name)
  if (versioncmp($facts['os']['release']['full'], '7.4') < 0) {
    warning("This version of simp-nfs may not work with ${facts['os']['name']} ${facts['os']['release']['full']}. Use simp-nfs module version < 7.0.0 instead")
  }

  include 'nfs::install'

  if $kerberos and (versioncmp($facts['os']['release']['major'], '8') < 0) {
# FIXME Must krb5 be installed to build the selinux policy that refers
# to krb5_conf_t?
#    include 'krb5'

    # This is here because the SELinux rules for directory includes in krb5
    # are broken in selinux-policy < 3.13.1-229.el7_6.9. It does no harm
    # on an EL7 system with the fixed selinux-policy.
    include 'nfs::selinux_hotfix'
    Class['nfs::selinux_hotfix'] -> Class['nfs::install']
  }

  if $ensure_latest_lvm2 {
    include 'nfs::lvm2'
    Class['nfs::lvm2'] -> Class['nfs::install']
  }

  if $is_client {
    include 'nfs::client'
    Class['nfs::install'] -> Class['nfs::client']
  }

  if $is_server {
    include 'nfs::server'
    Class['nfs::install'] -> Class['nfs::server']
  }
}
