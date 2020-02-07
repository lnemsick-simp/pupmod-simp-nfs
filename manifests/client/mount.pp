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
# @param port
#   The NFS port to which to connect
#
# @param nfs_version
#   The NFS major version that you want to use.  If you need to specify
#   an explicit minor version of NFSv4, include 'minorversion=<#>'in
#   `$options`.
#
# @param v4_remote_port
#   If using NFSv4, specify the remote port to which to connect
#
# @param sec
#   The sec mode for the mount
#
#   * Only valid with NFSv4
#
# @param options
#   The mount options string that should be used
#
#   * fstype and port will already be set for you
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
#
# @param autofs_add_key_subst
#   This enables map key substitution for a wildcard map key in an indirect map.
#
#   * Appends '/&' to the remote location.
#   * Only makes sense if ``autofs_indirect_map_key`` is set to '*', the
#     wildcard map key.
#
# @param stunnel
#   Controls enabling ``stunnel`` for this connection
#
#   * If left unset, the value will be taken from ``nfs::client::stunnel``
#   * May be set to ``false`` to ensure that ``stunnel`` will not be used for
#     this connection
#   * May be set to ``true`` to force the use of ``stunnel`` on this connection
#
# @param stunnel_systemd_deps
#   Add the appropriate ``systemd`` dependencies on systems that use ``systemd``
#
# @param stunnel_wantedby
#   The ``systemd`` targets that need ``stunnel`` to be active prior to being
#   activated
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
define nfs::client::mount (
  Simplib::Ip             $nfs_server,
  Stdlib::Absolutepath    $remote_path,
  Boolean                 $autodetect_remote       = true,
  Simplib::Port           $port                    = 2049,
  Integer[3,4]            $nfs_version             = 4,

# set this when you want to specify an explicit minor version of NFSv4 to use
# Should be set to 0 for NFSv4.0 to open the client delegation callback port
# through the firewall.
  Optional[Integer[0]]    $nfs_minor_version       = undef,

#FIXME this is for v4 stunnel connection...do we want
# to define here or use dlookup? Would be more clear if v4_stunnel_remote_port
  Optional[Simplib::Port] $v4_remote_port          = undef,
  Nfs::SecurityFlavor     $sec                     = 'sys',
  String                  $options                 = 'hard',
  Nfs::MountEnsure        $ensure                  = 'mounted',
  Boolean                 $at_boot                 = true,
  Boolean                 $autofs                  = true,
  Optional[String[1]]     $autofs_indirect_map_key = undef,
  Boolean                 $autofs_add_key_subst    = false,
  Optional[Boolean]       $stunnel                 = undef,
  Boolean                 $stunnel_systemd_deps    = true,
  Array[String]           $stunnel_wantedby        = ['remote-fs-pre.target']
) {
  if ($name !~ Stdlib::Absolutepath) {
    fail('"$name" must be of type Stdlib::Absolutepath')
  }

  include 'nfs::client'

  if ($nfs_version  == 4) {
    $_nfs_options = "-nfsvers=4,port=${port},${options},sec=${sec}"
  }
  else {
    $_nfs_options = "-nfsvers=3,port=${port},${options}"
  }

  if $stunnel !~ Undef {
    $_stunnel = $stunnel
  }
  else {
    $_stunnel = $nfs::client::stunnel
  }

#FIXME do the same thing with port (nfs::nfsd_port) as witn stunnel?
#would like to have definitive place for port definitions

  nfs::client::mount::connection { $name:
    nfs_server           => $nfs_server,
    nfs_version          => $nfs_version,
    nfs_port             => $port,
    v4_remote_port       => $v4_remote_port,
    stunnel              => $_stunnel,
    stunnel_wantedby     => $stunnel_wantedby
  }

  if $autofs {
    include 'autofs'

    Class['nfs::install'] -> Class['autofs::install']

    # This is a particular quirk about the autofs service ordering
#FIXME Is this still required?
# autofs.service Wants rpcbind.service and After rpcbind.service
#    Class['autofs::service'] ~> Service['rpcbind.service']

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

    if $_stunnel {
      # This is a workaround for issues with hooking into stunnel
      exec { 'refresh_autofs':
        command     => '/usr/bin/pkill -HUP -x automount',
        refreshonly => true,
        require     => Class['autofs::service']
      }

      # This is so that the automounter gets refreshed when *any* of the
      # related stunnel instances are refreshed
      Stunnel::Instance <| tag == 'nfs' |> ~> Exec['refresh_autofs']
    }

    if $_stunnel or ($autodetect_remote and $nfs::is_server) {
      if $autofs_add_key_subst {
        $_location = "127.0.0.1:${remote_path}/&"
      } else {
        $_location = "127.0.0.1:${remote_path}"
      }
    } else {
      if $autofs_add_key_subst {
        $_location = "${nfs_server}:${remote_path}/&"
      } else {
        $_location = "${nfs_server}:${remote_path}"
      }
    }

    autofs::map::entry { $_map_key:
      options  => "${_nfs_options}",
      location => $_location,
      target   => $_clean_name,
      require  => Nfs::Client::Mount::Connection[$name]
    }
  }
  else {
    if $_stunnel or ($autodetect_remote and $nfs::is_server) {
      $_device = "127.0.0.1:${remote_path}"
    } else {
      $_device = "${nfs_server}:${remote_path}"
    }

    mount { $name:
      ensure   => $ensure,
      atboot   => $at_boot,
      device   => $_device,
      fstype   => 'nfs', # NFS version specified in options
      options  => $_nfs_options,
      remounts => false,
      require  => Nfs::Client::Mount::Connection[$name]
    }
  }
}
