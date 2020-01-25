# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Set up the iptables hooks and the sysctl settings that are required for NFS
# to function properly on a client system.
#
# If using the ``nfs::client::stunnel::connect`` define, this will be
# automatically called for you.
#
# @param callback_port
#   The callback port
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
  Simplib::Port $callback_port = 876,
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

  # Normally, on the NFS client, the nfs kernel module would be loaded when
  # the first mount was executed.  However, to ensure NFS server to client
  # communication is on a known client port that can be allowed through the
  # firewall (i.e., not an ephemeral one), we need to configure the callback
  # port used by the nfs kernel module.  Here we (pre-)configure the kernel
  # parameter and load the module, if it is not already loaded. Then, in case
  # the module is already loaded, we also set the kernel parameter via sysctl.

  exec { 'modprobe_nfs':
    command => '/sbin/modprobe nfs',
    unless  => '/sbin/lsmod | /bin/grep -qw nfs',
 #   require => [
 #     Package['nfs-utils'],
 #     File['/etc/modprobe.d/nfs.conf']
 #   ],
    # The parameter is correctly set via /etc/modprobe.d/nfs.conf, but this
    # notify makes the setting visible through sysctl or anyone poking around
    # in /proc (i.e., following RHEL instructions for setting up NFS
    # through a firewall).
    notify  => Sysctl['fs.nfs.nfs_callback_tcpport']
  }

  sysctl { 'fs.nfs.nfs_callback_tcpport':
    ensure  => 'present',
    val     => $callback_port,
    silent  => true, #FIXME is this required?ignore the activation failure of a yet-to-be-activated sysctl value
    comment => 'Managed by simp-nfs Puppet module'
  }

#FIXME don't think this is needed.  think the notified sysctl is sufficient
#  file { '/etc/modprobe.d/nfs.conf':
#    owner   => 'root',
#    group   => 'root',
#    mode    => '0640',
#    content => "options nfs callback_tcpport=${callback_port}\n"
#  }

  service { 'nfs-client.target':
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
  }

  # ancillary services that need to be enabled or masked depending upon
  # how we are configured
  include 'nfs::service::nfsv3'
  include 'nfs::service::secure'

}
