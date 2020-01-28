# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::config
{
  assert_private()

  $_required_nfs_conf_opts = {
    'nfsd'   => {
      'port'        => $::nfs::nfsd_port,
      'vers2'       => false,
      'vers3'       => $::nfs::nfsv3,
      'vers4'       => $::nfs::server::nfsd_vers4,
      'vers4.0'     => $::nfs::server::nfsd_vers4_1,
      'vers4.1'     => $::nfs::server::nfsd_vers4_1,
      'vers4.2'     => $::nfs::server::nfsd_vers4_2
    },
    'mountd' => {
      'mountd_port' => $::nfs::mountd_port,
    }
  }

  if $::nfs::server::stunnel {
    # UDP can't be encapsulated by stunnel
    $_stunnel_opts = { 'nfsd' => { 'udp' => false } }
  } else {
    $_stunnel_opts = {}
  }

  $_merged_opts =  $::nfs::custom_nfs_conf_opts + $_required_nfs_conf_opts + $_stunnel_opts

  if 'exportfs' in $_merged_opts {
    concat::fragment { 'nfs_conf_exportfs':
      order   => 2,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs_conf_section.epp",
        { section => 'exportfs', opts => $_merged_opts['exportfs']})
    }
  }

  if $::nfs::nfsv3 {
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

    if 'RPCIDMAPDARGS' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCIDMAPDARGS':
        order   => 3,
        target  => '/etc/sysconfig/nfs',
        content => "RPCIDMAPDARGS=\"${::nfs::custom_daemon_args['RPCIDMAPDARGS']}\""
      }
    }

    if 'RPCMOUNTDARGS' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCNFSDARGS':
        order   => 4,
        target  => '/etc/sysconfig/nfs',
        content => "RPCMOUNTDARGS=\"${::nfs::custom_daemon_args['RPCMOUNTDARGS']}\""
      }
    }
    if 'RPCNFSDARGS' in $::nfs::custom_daemon_args {
      concat::fragment { 'nfs_RPCNFSDARGS':
        order   => 5,
        target  => '/etc/sysconfig/nfs',
        content => "RPCNFSDARGS=\"${::nfs::custom_daemon_args['RPCNFSDARGS']}\""
      }
    }
  }

  if $::nfs::server::custom_rpcrquotad_opts {
    $_rpcrquotadopts = "${::nfs::server::custom_rpcrquotad_opts} -p ${::nfs::rquotad_port}"
  } else {
    $_rpcrquotadopts = "-p ${::nfs::rquotad_port}"
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
  }

  # Ensure NFS starts with the proper number of slot entries.
  sysctl { 'sunrpc.tcp_slot_table_entries':
    ensure  => 'present',
    val     => $::nfs::server::sunrpc_tcp_slot_table_entries,
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  sysctl { 'sunrpc.udp_slot_table_entries':
    ensure  => 'present',
    val     => $::nfs::server::sunrpc_udp_slot_table_entries,
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }
}
