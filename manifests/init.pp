# Provides the base segments for NFS server *and* client services.
#
# @param is_server
#   Explicitly state that this system should be an NFS server
#
#   * Further configuration will need to be made via the ``nfs::server``
#     classes
#
# @param is_client
#   Explicitly state that this system should be an NFS client
#
#   * Further configuration will need to be made via the ```nfs::client``
#     classes
#
# @param nfsv3
#   Allow use NFSv3 for connections.
#
# @param mountd_nfs_v2
#   Act as an ``NFSv2`` server
#
# @param mountd_nfs_v3
#   Act as an ``NFSv3`` server
#
# @param rquotad_port
#   The port upon which ``rquotad`` on the NFS server should listen
#
# @param rpcrquotadopts
#   Options that should be passed to ``rquotad`` at start time.
#
#   * **NOTE::** $rquotad_port will be automatically added to this string
#     via the `-p` option.
#
# @param lockd_tcpport
#   The TCP port upon which ``lockd`` should listen (NFSv3)
#
# @param lockd_udpport
#   The UDP port upon which ``lockd`` should listen (NFSv3)
#
# @param rpcnfsdargs
#   Arbitrary arguments to pass to ``nfsd``
#
#   * The defaults disable ``NFSv2`` from being served to clients
#
# @param rpcnfsdcount
#   The number of NFS server threads to start by default
#
# @param nfsd_v4_grace
#   The NFSv4 grace period, in seconds
#
# @param mountd_port
#   The port upon which ``mountd`` should listen
#
# @param statd_port
#   The port upon which ``statd`` should listen
#
# @param statd_outgoing_port
#   The port that ``statd`` will use when connecting to client systems
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
#   Whether the NFS server will pull its  keytab directly from the Puppet server.
#
#   * Only applicable if ``$kerberos` is ``true.
#   * If ``false``, you will need to ensure the appropriate services are restarted
#     when the keytab is changed.
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @param stunnel
#   Wrap ``stunnel`` around the NFS server connections
#
#   * This is ideally suited for environments without a working Kerberos setup
#     and may cause issues when used with Kerberos.
#
# @param stunnel_tcp_nodelay
#   Enable TCP_NODELAY for all stunnel connections
#
# @param stunnel_socket_options
#   Additional socket options to set for stunnel connections
#
# @param stunnel_systemd_deps
#
# @param stunnel_wantedby
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs (
  Boolean               $is_server              = false,
  Boolean               $is_client              = true,
  Boolean               $nfsv3                  = false,
  Boolean               $mountd_nfs_v2          = false,
  Boolean               $mountd_nfs_v3          = false,
  Simplib::Port         $rquotad_port           = 875,
  Optional[String]      $rpcrquotadopts         = undef,
  Simplib::Port         $mountd_port            = 20048,

  Boolean               $gssd_avoid_dns         = true, # false is considered a security hole
  Boolean               $gssd_limit_to_legacy_enctypes = false, # do not want old ciphers
  Boolean               $gssd_use_gss_proxy     = true,
  Simplib::Port         $lockd_port             = 32803,
  Simplib::Port         $lockd_udp_port         = 32769,
  Simplib::Port         $sm_notify_outgoing_port = 6620, #FIXME???
  Simplib::Port         $statd_port             = 662,
  Simplib::Port         $statd_outgoing_port    = 2020,
  Nfs::NfsConfHash      $custom_nfs_conf_opts   = {},
  Nfs::LegacyDaemonArgs $custom_daemon_args     = {},  # only applies to EL7
  Boolean               $secure_nfs             = false,
  Boolean               $ensure_latest_lvm2     = true,
  Boolean               $kerberos               = simplib::lookup('simp_options::kerberos', { 'default_value' => false }),
  Boolean               $keytab_on_puppet       = simplib::lookup('simp_options::kerberos', { 'default_value' => true}),
  Boolean               $firewall               = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
  Boolean               $tcpwrappers            = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false }),
  Boolean               $stunnel                = simplib::lookup('simp_options::stunnel', { 'default_value' => false }),
  Boolean               $stunnel_tcp_nodelay    = true,
  Array[String]         $stunnel_socket_options = [],
  Boolean               $stunnel_systemd_deps   = true,
  Array[String]         $stunnel_wantedby       = []
) {

  simplib::assert_metadata($module_name)
  if (versioncmp($facts['os']['release']['full'], '7.4') < 0) {
    warning("This version of simp-nfs may not work with ${facts['os']['name]} ${facts['os']['release']['full']}. Use simp-nfs module version < 7.0.0 instead")
  }

  if $stunnel_tcp_nodelay {
    $_stunnel_socket_options = $stunnel_socket_options + [
      'l:TCP_NODELAY=1',
      'r:TCP_NODELAY=1'
    ]
  }
  else {
    $_stunnel_socket_options = $stunnel_socket_options
  }

  include 'nfs::service_names'
  include 'nfs::install'
  include 'nfs::base_config'

  Class['nfs::install'] -> Class['nfs::base_config']

#FIXME if we are notifying client and/or server classes and they have the services
# listed, do we need this?  Each el7 service will regenerate its config when it
# is run
  # This service needs to be restarted when configuration changes.  It will do any
  # config massaging necessary (el7) and then restart base services needed by
  # the NFS server and client.
  # * Still need to reload nfs-server.service
  # * On el7 it will regenerate /run/sysconfig/nfs-utils from /etc/sysconfig/nfs first)
  exec { 'nfs_utils_restart':
    command     => 'systemctl restart nfs-utils',
    require     => Class['nfs::install'],
    refreshonly => true
  }

#  Class['nfs::base_config'] ~> Exec['nfs_utils_restart']


  if $kerberos {
    include 'krb5'

    # This is here because the SELinux rules for directory includes in krb5
    # are broken.
    include 'nfs::selinux_hotfix'
    Class['nfs::selinux_hotfix'] -> Class['nfs::install']

    if $keytab_on_puppet {
      include 'krb5::keytab'
    }
  }

  if $ensure_latest_lvm2 {
    include 'nfs::lvm2'

    Class['nfs::lvm2'] -> Class['nfs::install']
  }

  if $is_client {
    include 'nfs::client'

    Class['nfs::base_config'] ~> Class['nfs::client']

    # VERIFY this is needed
    if $kerberos {
      Class['krb5'] ~> Class['nfs::client']

#FIXME move to comment for keytab_on_puppet param
      # If you don't put your keytabs on the Puppet server, you'll need to add
      # code to trigger this yourself!
      if $keytab_on_puppet {
        Class['krb5::keytab'] ~> Class['nfs::client']
      }
    }
  }

  if $is_server {
    include 'nfs::server'

    Class['nfs::base_config'] ~> Class['nfs::server']

    if $kerberos {
      Class['krb5'] ~> Class['nfs::server']

      if $keytab_on_puppet {
        Class['krb5::keytab'] ~> Class['nfs::server']
      }
    }
  }

}
