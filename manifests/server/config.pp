# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::config
{
  assert_private()

  # Required config options for all possible NFS server services.
  # * Augments the base config shared with NFS client.
  # * Only config appropriate for specified NFS versions will actually be set.
  # * Will override any user-input options, because firewall and stunnels
  #   will not work otherwise!
  $_required_nfs_conf_opts = {
    'mountd' => {
      'mountd_port' => $nfs::mountd_port,
    },
    'nfsd'   => {
      'port'        => $nfs::nfsd_port,
      'vers2'       => false,
      'vers3'       => $nfs::nfsv3,
      'vers4'       => $nfs::server::nfsd_vers4,
      'vers4.0'     => $nfs::server::nfsd_vers4_0,
      'vers4.1'     => $nfs::server::nfsd_vers4_1,
      'vers4.2'     => $nfs::server::nfsd_vers4_2
    },
  }

  if $nfs::server::stunnel {
    # UDP can't be encapsulated by stunnel, so we have to force this
    # setting.
    $_stunnel_opts = { 'nfsd' => { 'tcp' => true, 'udp' => false } }
  } else {
    $_stunnel_opts = {}
  }

  $_merged_opts = deep_merge($nfs::custom_nfs_conf_opts,
    $_required_nfs_conf_opts, $_stunnel_opts)

  if 'exportfs' in $_merged_opts {
    concat::fragment { 'nfs_conf_exportfs':
      order   => 2,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'exportfs', opts => $_merged_opts['exportfs']})
    }
  }

  if $nfs::nfsv3 {
    if 'mountd' in $_merged_opts {
      concat::fragment { 'nfs_conf_mountd':
        order   => 5,
        target  => '/etc/nfs.conf',
        content => epp("${module_name}/etc/nfs_conf_section.epp",
          { section => 'mountd', opts => $_merged_opts['mountd']})
      }
    }
  }

  concat::fragment { 'nfs_conf_nfsd':
    order   => 6,
    target  => '/etc/nfs.conf',
    content => epp("${module_name}/etc/nfs_conf_section.epp",
      { section => 'nfsd', opts => $_merged_opts['nfsd']})
  }

  if 'nfsdcltrack' in $_merged_opts {
    concat::fragment { 'nfs_conf_nfsdcltrack':
      order   => 7,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'nfsdcltrack', opts => $_merged_opts['nfsdcltrack']})
    }
  }

  if (versioncmp($facts['os']['release']['major'], '8') < 0) {
    # In EL > 7, NFS services must be configured by /etc/nfs.conf. In EL7, however,
    # /etc/sysconfig/nfs is still needed to allow configuration of a handful of NFS
    # daemon command line options that were not yet migrated to /etc/nfs.conf.

    if 'RPCIDMAPDARGS' in $nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCIDMAPDARGS':
        order   => 3,
        target  => '/etc/sysconfig/nfs',
        content => "RPCIDMAPDARGS=\"${nfs::custom_daemon_args['RPCIDMAPDARGS']}\""
      }
    }


    if 'RPCMOUNTDARGS' in $nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCNFSDARGS':
        order   => 4,
        target  => '/etc/sysconfig/nfs',
        content => "RPCMOUNTDARGS=\"${nfs::custom_daemon_args['RPCMOUNTDARGS']}\""
      }
    }

    # Work around problem when using '/etc/nfs.conf' and '/etc/sysconfig/nfs'.
    # The config conversion script will set the number of threads on the
    # rpc.nfsd command line based on a RPCNFSDCOUNT environment variable or
    # a default value of 8.  Since command line arguments take precedence over
    # nfs.conf settings, this causes the threads nfsd setting in nfs.conf
    # to be ignored.
    if 'threads' in $_merged_opts['nfsd'] {
      concat::fragment { 'nfs_RPCNFSDCOUNT':
        order   => 5,
        target  => '/etc/sysconfig/nfs',
        content => "RPCNFSDCOUNT=\"${_merged_opts['nfsd']['threads']}\""
      }
    }

    if 'RPCNFSDARGS' in $nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCNFSDARGS':
        order   => 5,
        target  => '/etc/sysconfig/nfs',
        content => "RPCNFSDARGS=\"${nfs::custom_daemon_args['RPCNFSDARGS']}\""
      }
    }

  }

  if $nfs::server::custom_rpcrquotad_opts {
    $_rpcrquotadopts = "${nfs::server::custom_rpcrquotad_opts} -p ${nfs::rquotad_port}"
  } else {
    $_rpcrquotadopts = "-p ${nfs::rquotad_port}"
  }

  $_sysconfig_rpc_rquotad = @("SYSCONFIGRPCRQUOTAD")
    # This file is managed by Puppet (simp-nfs module).  Changes will be overwritten
    # at the next puppet run.
    #
    RPCRQUOTADOPTS=${_rpcrquotadopts}
    | SYSCONFIGRPCRQUOTAD

  file { '/etc/sysconfig/rpc-rquotad':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $_sysconfig_rpc_rquotad
  }

  concat { '/etc/exports':
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    ensure_newline => true,
    warn           => true,
    notify         => Exec['nfs_re-export']
  }

  exec { 'nfs_re-export':
    command     => '/usr/sbin/exportfs -ra',
    refreshonly => true,
    logoutput   => true,
    # Don't execute if nfsd kernel module has not been loaded yet, (i.e.,
    # nfs-server.service is not running) or will fail with obscure
    # 'Function not implemented' error. The changes will be picked up when
    # nfs-server.service starts, as its unit file runs 'exportfs -r'.
    onlyif      => '/sbin/lsmod | /usr/bin/grep -qw nfsd'
  }

  # Tune with the proper number of slot entries.
  #FIXME Is this still applicable?  Also, should we persist to file
  # in /etc/modprobe.d so that it is available at boot time, just
  # like the kernel module settings for nfs(v4)?
  sysctl { 'sunrpc.tcp_slot_table_entries':
    ensure  => 'present',
    val     => $nfs::server::sunrpc_tcp_slot_table_entries,
    # Ignore failure if var-lib-nfs-rpc_pipefs.mount is not up yet.
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  sysctl { 'sunrpc.udp_slot_table_entries':
    ensure  => 'present',
    val     => $nfs::server::sunrpc_udp_slot_table_entries,
    # Ignore failure if var-lib-nfs-rpc_pipefs.mount is not up yet.
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  if $nfs::tcpwrappers {
    include 'nfs::server::tcpwrappers'
  }
}
