# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server::config
{
  assert_private()

  $_required_opts = {
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

  $_merged_opts =  $custom_nfs_conf_opts + $_required_nfs_conf_opts

  if 'exportfs' in $_merged_opts {
    concat::fragment { 'nfs_conf_exportfs':
      order   => 2,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'exportfs', opts => $_merged_opts['exportfs']})
    }
  }

  if $nfsv3 {
    if 'mountd' in $_merged_opts {
      concat::fragment { 'nfs_conf_mountd':
        order   => 5,
        target  => '/etc/nfs.conf',
        content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
          { section => 'mountd', opts => $_merged_opts['mountd']})
      }
    }
  }

  if 'nfsd' in $_merged_opts {
    concat::fragment { 'nfs_conf_nfsd':
      order   => 6,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'nfsd', opts => $_merged_opts['nfsd']})
    }
  }

  if 'nfsdcltrack' in $_merged_opts {
    concat::fragment { 'nfs_conf_nfsdcltrack':
      order   => 7,
      target  => '/etc/nfs.conf',
      content => epp("${module_name}/etc/nfs/nfs_conf_section.epp",
        { section => 'nfsdcltrack', opts => $_merged_opts['nfsdcltrack']})
    }
  }


  #FIXME configure rpc.rquotad

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
    require     => Service['nfs-server.service']
  }

  # Ensure NFS starts with the proper number of slot entries.
  sysctl { 'sunrpc.tcp_slot_table_entries':
    ensure  => 'present',
    val     => $sunrpc_tcp_slot_table_entries,
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module',
    notify  => Service[$::nfs::service_names::nfs_server]  #FIXME is this necessary?
  }

  sysctl { 'sunrpc.udp_slot_table_entries':
    ensure  => 'present',
    val     => $sunrpc_udp_slot_table_entries,
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module',
    notify  => Service[$::nfs::service_names::nfs_server]
  }

}
