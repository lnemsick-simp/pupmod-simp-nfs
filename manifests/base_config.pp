# @summary Common configuration required by both NFS server and client
#
class nfs::base_config (
  Boolean               $nfsv3                         = $::nfs::nfsv3,
  Boolean               $gssd_avoid_dns                = $::nfs::gssd_avoid_dns,
  Boolean               $gssd_limit_to_legacy_enctypes = $::nfs::gssd_limit_to_legacy_enctypes,
  Boolean               $gssd_use_gss_proxy            = $::nfs::gssd_use_gss_proxy,
  Simplib::Port         $lockd_port                    = $::nfs::lockd_port,
  Simplib::Port         $lockd_udp_port                = $::nfs::lockd_udp_port,
  Simplib::Port         $sm_notify_outgoing_port       = $::nfs::sm_notify_outgoing_port,
  Simplib::Port         $statd_port                    = $::nfs::statd_port,
  Simplib::Port         $statd_outgoing_port           = $::nfs::statd_outgoing_port,
  Nfs::NfsConfHash      $custom_nfs_conf_opts          = $::nfs::custom_nfs_conf_options,
  Nfs::LegacyDaemonArgs $custom_daemon_args            = $::nfs::custom_daemon_args,
  Boolean               $secure_nfs                    = $::nfs::secure_nfs

) {
  assert_private()

  $_required_opts = {
    'gssd'     => {
      'avoid-dns'                => $gssd_avoid_dns,
      'limit-to-legacy-enctypes' => $gssd_limit_to_legacy_enctypes,
      'use-gss-proxy'            => $gssd_use_gss_proxy
    },
    'lockd'     => {
      'port'                     => $lockd_port,
      'udp-port'                 => $lockd_udp_port,
    },
    'sm-notify' => {
      'outgoing-port' => $sm_notify_outgoing_port
    },
    'statd'     => {
      'port'                     => $statd_port,
      'outgoing-port'            => $statd_outgoing_port
    }
  }

  $_merged_opts =  $custom_nfs_conf_opts + $_required_nfs_conf_opts

  # Use concat so users can add new sections on their own, in the event NFS
  # configuration changes and this module has not yet been updated.
  concat { '/etc/nfs.conf':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true,
    # Fragments in this module are ordered so that in a file containing all
    # sections (e.g., one with base and server config), the general section
    # comes first and all other sections are in alphabetical order.
    order          => 'numeric'
  }

  if 'general' in $_merged_opts {
    concat::fragment { 'nfs_conf_general':
      order   => 1,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'general', opts => $_merged_opts['general']})
    }
  }

  if $secure_nfs {
    concat::fragment { 'nfs_conf_gssd':
      order   => 3,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'gssd', opts => $_merged_opts['gssd']})
    }
  }

  if $nfsv3 {
    concat::fragment { 'nfs_conf_lockd':
      order   => 4,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'lockd', opts => $_merged_opts['lockd']})
    }

    concat::fragment { 'nfs_conf_sm_notify':
      order   => 8,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'sm-notify', opts => $_merged_opts['sm-notify']})
    }

    if 'statd' in $_merged_opts {
      concat::fragment { 'nfs_conf_statd':
        order   => 1,
        target  => '/etc/nfs.conf',
        content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
          { section => 'statd', opts => $_merged_opts['statd']})
      }
    }
  }

  if (versioncmp($facts['os']['release']['major'], '8') < 0) {
    # In EL > 7, NFS services must be configured by /etc/nfs.conf. In EL7, however,
    # /etc/sysconfig/nfs is still needed to enable use of gssproxy and to allow
    # configuration of a handful of NFS daemon command line options that were not
    # yet migrated to /etc/nfs.conf.
    #
    # NFS services actually use /run/sysconfig/nfs-utils, not /etc/sysconfig/nfs.
    # However, that file is (re-)generated from /etc/sysconfig/nfs every time
    # a NFS service that requires it is started.  So, /etc/sysconfig/nfs is
    # still the correct location for this configuration.
    concat { '/etc/sysconfig/nfs':
      owner          => 'root',
      group          => 'root',
      mode           => '0644',
      ensure_newline => true,
      warn           => true
    }

    if $secure_nfs and $gssd_use_gss_proxy  {
      # The 'use-gss-proxy' option in /etc/nfs.conf is not used in EL7.
      # Need to set GSS_USE_PROXY service env variable instead.
      concat::fragment { 'nfs_gss_use_proxy':
        order   => 1,
        target  => '/etc/sysconfig/nfs',
        content => "GSS_USE_PROXY=yes"
      }
    }

    if 'GSSDARGS' in $custom_daemon_args {
      concat::fragment { 'nfs_GSSDARGS':
        order   => 2,
        target  => '/etc/sysconfig/nfs',
        content => "GSSDARGS=\"${custom_daemon_args['GSSDARGS']}\""
      }
    }

    if 'SMNOTIFYARGS' in $custom_daemon_args {
      concat::fragment { 'nfs_SMNOTIFYARGS':
        order   => 2,
        target  => '/etc/sysconfig/nfs',
        content => "SMNOTIFYARGS=\"${custom_daemon_args['SMNOTIFYARGS']}\""
      }
    }
  } else {
    # To support upgrades to EL8, the nfs-utils RPM provides and enables
    # the nfs-convert.service which is run when NFS services are started.
    # It generates /etc/nfs.conf from /etc/sysconfig/nfs and then moves
    # /etc/sysconfig/nfs to a backup file.
    file { '/etc/sysconfig/nfs':
      ensure => 'absent',
      before => Concat['/etc/nfs.conf']
    }
  }
}
