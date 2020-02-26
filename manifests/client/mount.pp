# Set up a NFS client to point to be mounted, optionally using autofs
#
# @param name
#   The local mount path
#
#   * When not using autofs (``autofs`` is ``false``), this will be a static
#     mount and you must ensure the target directory exists.  This define will
#     **NOT** create the target directory for you.
#
#   * When using autofs (``autofs`` is ``true``):
#
#     * autofs will create the target directory for you (full path).
#     * If ``autofs_indirect_map_key`` is unset, a direct mount will be created
#       for this path.
#     * If ``autofs_indirect_map_key`` is set, an indirect mount will be created:
#       * ``name`` will be the mount point
#       * ``autofs_indirect_map_key`` will be the map key and can be '*', the
#         wildcard map key indicator
#
# @param nfs_server
#   The IP address of the NFS server to which you will be connecting
#
#   * If you are the server, please make sure that this is ``127.0.0.1``
#
# @param remote_path
#   The NFS share that you want to mount
#
# @param autodetect_remote
#   This should be set to ``false`` if you want to ignore any 'intelligent'
#   guessing as to whether or not your system is the NFS server.
#
#   For instance, if you are an NFS server, but want to mount an NFS share on a
#   remote system, then you will need to set this to ``false`` to ensure that
#   your mount is not set to ``127.0.0.1`` based on the detection that you are
#   also an NFS server.
#
# @param nfs_version
#   The NFS major version that you want to use.  If you need to specify
#   an explicit minor version of NFSv4, include 'minorversion=<#>'in
#   `$options`.
#
# @param sec
#   The sec mode for the mount
#
#   * Only valid with NFSv4
#
# @param options
#   String containing comma-separated list of additional mount options
#
#   * fstype, nfsvers, and port will already be set for you
#   * sec will be set for you for NFSv4
#   * If using stunnel with NFSv4, proto will be set to tcp for you
#   * If using stunnel with NFSv3, proto and mountproto will both be set to
#     tcp for you.
#
# @param ensure
#   The mount state of the specified mount point
#
#   * ``mounted``   => Ensure that the mount point is actually mounted
#   * ``present``   => Just add the entry to the fstab and do not mount it
#   * ``unmounted`` => Add the entry to the fstab and ensure that it is not
#                      mounted
#   * Has no effect if ``$autofs`` is set
#
# @param at_boot
#   Ensure that this mount is mounted at boot time
#
#   * Has no effect if ``$autofs`` is set
#
# @param autofs
#   Enable automounting with Autofs
#
# @param autofs_add_key_subst
#   This enables map key substitution for a wildcard map key in an indirect map.
#
#   * Appends '/&' to the remote location.
#   * Only makes sense if ``autofs_indirect_map_key`` is set to '*', the
#     wildcard map key.
#
# @param nfsd_port
#   The NFS port to which to connect
#
# @param stunnel
#   Controls enabling ``stunnel`` for this connection
#
#   * If left unset, the value will be taken from ``nfs::client::stunnel``
#   * May be set to ``false`` to ensure that ``stunnel`` will not be used for
#     this connection
#   * May be set to ``true`` to force the use of ``stunnel`` on this connection
#
# @param stunnel_wantedby
#   The ``systemd`` targets that need ``stunnel`` to be active prior to being
#   activated
#
#   * If left unset, the value will be taken from ``nfs::client::stunnel_wantedby``
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount (
  Simplib::Ip             $nfs_server,
  Stdlib::Absolutepath    $remote_path,
  Boolean                 $autodetect_remote       = true,
  Integer[3,4]            $nfs_version             = 4,
  Nfs::SecurityFlavor     $sec                     = 'sys',
  String                  $options                 = 'soft',
  Nfs::MountEnsure        $ensure                  = 'mounted',
  Boolean                 $at_boot                 = true,
  Boolean                 $autofs                  = true,
  Boolean                 $autofs_add_key_subst    = false,
  Optional[String[1]]     $autofs_indirect_map_key = undef,
  Optional[Simplib::Port] $nfsd_port               = undef,
  Optional[Boolean]       $stunnel                 = undef,
  Optional[Simplib::Port] $stunnel_nfsd_port       = undef,
  Optional[Array[String]] $stunnel_socket_options  = undef,
  Optional[Integer]       $stunnel_verify          = undef,
  Optional[Array[String]] $stunnel_wantedby        = undef
) {
  if ($name !~ Stdlib::Absolutepath) {
    fail('"$name" must be of type Stdlib::Absolutepath')
  }

  include 'nfs::client'

  if ($nfs_version == 3) and !$nfs::nfsv3 {
    fail('Cannot mount NFSv3 when NFSv3 is not enabled on client.  Set nfs::nfsv3 to true to fix.')
  }


  #############################################################
  # Pull in defaults from nfs and nfs::client classes as needed
  #############################################################
  if $nfsd_port !~ Undef {
    $_nfsd_port = $nfsd_port
  } else {
    $_nfsd_port = $nfs::nfsd_port
  }

  if $stunnel !~ Undef {
    $_stunnel = $stunnel
  } else {
    $_stunnel = $nfs::client::stunnel
  }

  if ($nfs_version == 3) and $_stunnel {
    fail("NFSv3 mounts with stunnel are unsupported.  Set 'stunnel' to false for Nfs::Client::Mount[${name}] to fix.")
  }

  if $stunnel_nfsd_port !~ Undef {
    $_stunnel_nfsd_port = $stunnel_nfsd_port
  } else {
    $_stunnel_nfsd_port = $nfs::stunnel_nfsd_port
  }

  if $stunnel_socket_options !~ Undef {
    $_stunnel_socket_options = $stunnel_socket_options
  } else {
    $_stunnel_socket_options = $nfs::client::stunnel_socket_options
  }

  if $stunnel_verify !~ Undef {
    $_stunnel_verify = $stunnel_verify
  } else {
    $_stunnel_verify = $nfs::client::stunnel_verify
  }

  if $stunnel_wantedby !~ Undef {
    $_stunnel_wantedby = $stunnel_wantedby
  } else {
    $_stunnel_wantedby = $nfs::client::stunnel_wantedby
  }

  #################################
  # Configure connection and mount
  #################################

  if ($nfs_version  == 4) {
    $_nfs_base_options = "nfsvers=4,port=${_nfsd_port},${options},sec=${sec}"
  } else {
    $_nfs_base_options = "nfsvers=3,port=${_nfsd_port},${options}"
  }

  if $_stunnel {
    # stunnel only carries TCP
    $_nfs_options = "${_nfs_base_options},proto=tcp"
  } else {
    $_nfs_options = $_nfs_base_options
  }

  if $_stunnel or ($autodetect_remote and $nfs::is_server) {
    $_remote = "127.0.0.1:${remote_path}"
  } else {
    $_remote = "${nfs_server}:${remote_path}"
  }

  nfs::client::mount::connection { $name:
    nfs_server             => $nfs_server,
    nfs_version            => $nfs_version,
    nfsd_port              => $_nfsd_port,
    firewall               => $nfs::firewall,
    stunnel                => $_stunnel,
    stunnel_nfsd_port      => $_stunnel_nfsd_port,
    stunnel_socket_options => $_stunnel_socket_options,
    stunnel_verify         => $_stunnel_verify,
    stunnel_wantedby       => $_stunnel_wantedby,
    tcpwrappers            => $nfs::tcpwrappers
  }

  if $autofs {
    include 'autofs'

    Class['nfs::install'] -> Class['autofs::install']

    if $autofs_indirect_map_key {
      $_mount_point = $name
      $_map_key = $autofs_indirect_map_key
    } else {
      $_mount_point = '/-'
      $_map_key = $name
    }

    # The map name is very particular
    $_clean_name = regsubst( regsubst($name, '^/', ''), '/', '__', 'G' )
    $_map_name = sprintf('/etc/autofs/%s.map', $_clean_name)

    autofs::map::master { $name:
      mount_point => $_mount_point,
      map_name    => $_map_name,
      require     => Nfs::Client::Mount::Connection[$name]
    }

    if $autofs_add_key_subst {
      $_location = "${_remote}/&"
    } else {
      $_location = $_remote
    }

    autofs::map::entry { $_map_key:
      options  => "-${_nfs_options}",
      location => $_location,
      target   => $_clean_name,
      require  => Nfs::Client::Mount::Connection[$name]
    }

    if $_stunnel {
      # This is a workaround for issues with hooking into stunnel
      $_exec_attributes = {
        command     => '/usr/bin/systemctl reload autofs',
        refreshonly => true,
        require     => Class['autofs::service']
      }

      ensure_resource( 'exec', 'reload_autofs', $_exec_attributes)

      # This is so that the automounter gets reloaded when *any* of the
      # related stunnel instances are refreshed
      Stunnel::Instance <| tag == 'nfs' |> ~> Exec['reload_autofs']
    }

  } else {
    mount { $name:
      ensure   => $ensure,
      atboot   => $at_boot,
      device   => $_remote,
      fstype   => 'nfs', # EL>6 NFS version specified in options not fstype
      options  => $_nfs_options,
      remounts => false,
      require  => Nfs::Client::Mount::Connection[$name]
    }
  }
}
