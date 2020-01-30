# @summary Common configuration required by both NFS server and client
#
class nfs::base_config
{
  assert_private()

  $_required_nfs_conf_opts = {
    'gssd'     => {
      'avoid-dns'                => $::nfs::gssd_avoid_dns,
      'limit-to-legacy-enctypes' => $::nfs::gssd_limit_to_legacy_enctypes,
      'use-gss-proxy'            => $::nfs::gssd_use_gss_proxy
    },
    'lockd'     => {
      'port'                     => $::nfs::lockd_port,
      'udp-port'                 => $::nfs::lockd_udp_port,
    },
    'sm-notify' => {
      'outgoing-port'            => $::nfs::sm_notify_outgoing_port
    },
    'statd'     => {
      'port'                     => $::nfs::statd_port,
      'outgoing-port'            => $::nfs::statd_outgoing_port
    }
  }

  $_merged_opts =  $::nfs::custom_nfs_conf_opts + $_required_nfs_conf_opts

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
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'general', opts => $_merged_opts['general']})
    }
  }

  if $::nfs::secure_nfs {
    concat::fragment { 'nfs_conf_gssd':
      order   => 3,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'gssd', opts => $_merged_opts['gssd']})
    }
  }

  if $::nfs::nfsv3 {
    concat::fragment { 'nfs_conf_lockd':
      order   => 4,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'lockd', opts => $_merged_opts['lockd']})
    }

    concat::fragment { 'nfs_conf_sm_notify':
      order   => 8,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'sm-notify', opts => $_merged_opts['sm-notify']})
    }

    if 'statd' in $_merged_opts {
      concat::fragment { 'nfs_conf_statd':
        order   => 9,
        target  => '/etc/nfs.conf',
        content => epp("${module_name}/etc/nfs_conf_section.epp",
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

    if $::nfs::secure_nfs and $::nfs::gssd_use_gss_proxy  {
      # The 'use-gss-proxy' option in /etc/nfs.conf is not used in EL7.
      # Need to set GSS_USE_PROXY service env variable instead.
      concat::fragment { 'nfs_gss_use_proxy':
        order   => 1,
        target  => '/etc/sysconfig/nfs',
        content => "GSS_USE_PROXY=yes"
      }
    }

    if 'GSSDARGS' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_GSSDARGS':
        order   => 2,
        target  => '/etc/sysconfig/nfs',
        content => "GSSDARGS=\"${::nfs::custom_daemon_args['GSSDARGS']}\""
      }
    }

    if 'SMNOTIFYARGS' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_SMNOTIFYARGS':
        order   => 6,
        target  => '/etc/sysconfig/nfs',
        content => "SMNOTIFYARGS=\"${::nfs::custom_daemon_args['SMNOTIFYARGS']}\""
      }
    }

    # The variable in /etc/sysconfig/nfs is $STATDARG but is written to
    # /run/sysconfig/nfs-utils as STATDARGS.
    if 'STATDARG' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_STATDARG':
        order   => 7,
        target  => '/etc/sysconfig/nfs',
        content => "STATDARG=\"${::nfs::custom_daemon_args['STATDARG']}\""
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

  if $::nfs::idmapd {
    include 'nfs::idmapd::config'
  }
}
