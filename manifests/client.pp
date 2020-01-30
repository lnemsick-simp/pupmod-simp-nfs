# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Set up the iptables hooks and the sysctl settings that are required for NFS
# to function properly on a client system.
#
# If using the ``nfs::client::stunnel::connect`` define, this will be
# automatically called for you.
#
# @param callback_port
#   The port used by the server to recall delegation of responsibilities to a
#   client in NFSv4.0.  Beginning with NFSv4.1, a separate callback side channel
#   is not required.
#
# @param stunnel
#   Enable ``stunnel`` connections for this system
#
#   * Will *attempt* to determine if the server is trying to connect to itself
#
#   * If connecting to itself, will not use stunnel, otherwise will use stunnel
#
#   * If you are using host aliases for your NFS server names, this check
#     may fail and you may need to disable ``$stunnel`` explicitly
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
#   * See ``stunnel::connection::verify`` for details
#
# @param firewall
#   Use the SIMP IPTables module to manipulate the firewall settings
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::client (
  Simplib::Port $callback_port  = 876,    # NFSV4.0
  Boolean       $blkmap         = false,  # NFSV4.1 or later
  Boolean       $stunnel        = $::nfs::stunnel,
  Integer[0]    $stunnel_verify = 2,
  Boolean       $firewall       = $::nfs::firewall
) inherits ::nfs {

  assert_private()

  if !$nfs::is_server {
    file { '/etc/exports':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "\n"
    }
  }

  # We need to configure the NFSv4.0 client delegation callback port for the
  # nfsv4 kernel module, to ensure the port will pass through a firewall (i.e.,
  # is not ephemeral).  Normally, the nfsv4 kernel module would be loaded when
  # the mount requiring it is executed.  This dynamic loading doesn't play
  # well with sysctl.  So, we are going to ensure the kernel module is
  # configured properly with a static configuration file, load the module if
  # necessary, and, in case it was already loaded, set the value by sysctl.
  #
  # NOTE: The parameter has to be configured via the nfs kernel module (a
  # dependency of the nfsv4 kernel module), but won't be activated until the
  # nfsv4 module is loaded.
  #
  exec { 'modprobe_nfsv4':
    command => '/sbin/modprobe nfsv4',
    unless  => '/sbin/lsmod | /usr/bin/grep -qw nfsv4',
    require =>  File['/etc/modprobe.d/nfs.conf'],
    notify  => Sysctl['fs.nfs.nfs_callback_tcpport']
  }

  sysctl { 'fs.nfs.nfs_callback_tcpport':
    ensure  => 'present',
    val     => $callback_port,
    # Ignore 'invalid' kernel parameter, because the sysctl custom type caches
    # all kernel param info the first time any sysctl resource is created. So,
    # the parameter may appear to not be activated, even when it has just been
    # activated by the module we loaded in Exec['modprobe_nfsv4'].
    silent  => true,
    comment => 'Managed by simp-nfs Puppet module'
  }

  file { '/etc/modprobe.d/nfs.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => "options nfs callback_tcpport=${callback_port}\n"
  }

  service { 'nfs-client.target':
    ensure     => 'running',
    enable     => true,
    hasrestart => true
  }

  if $blkmap {
    service { 'nfs-blkmap.service':
      ensure     => 'running',
      enable     => true,
      hasrestart => true
    }
  }

  if $::nfs::idmapd {
    include 'nfs::idmapd::client'
  }
}
