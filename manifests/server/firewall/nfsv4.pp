# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Configure a NFS server with a default configuration that nails up the ports
# so that you can pass them through ``iptables``.
#
# This defaults to ``NFSv4``.
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to ``any`` or ``ALL`` to allow the world
#
# @param nfsv3
#   Serve out ``NFSv3`` shares
#
#
# @param lockd_arg
#   Options that should be passed to ``lockd`` at start time
#
# @param nfsd_module
#   If set to ``noload`` will prevent the ``nfsd`` kernel module from being
#   pre-loaded
#
#   * **NOTE:** if this is set to _anything_, the template will say ``noload``
#
# @param rpcmountdopts
#   An arbitrary string of options to pass to ``mountd`` at start time
#
# @param statdarg
#   An arbitrary string of options to pass to ``statd`` at start time
#
# @param statd_ha_callout
#   The path to an application that should be used for ``statd`` HA
#
# @param rpcidmapdargs
#   Arbibrary arguments to pass to ``idmapd`` at start time
#
# @param rpcgssdargs
#   Arbitrary arguments to pass to ``gssd`` at start time
#
# @param rpcsvcgssdargs
#   Arbitrary arguments to pass to ``svcgssd`` at start time
#
# @param sunrpc_udp_slot_table_entries
#
#   Set the default UDP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @param sunrpc_tcp_slot_table_entries
#
#   Set the default TCP slot table entries in the kernel
#
#   * Most NFS server performance guides seem to recommend this setting
#
#   * If you have a low memory system, you may want to reduce this
#
# @note Due to a bug in EL, ``$mountd_nfs_v1`` must be set to ``yes`` to
#   properly unmount
#
# @note The ``rpcbind`` port and the ``rpc.quotad`` ports are open to the
#   trusted networks so that the ``quota`` command works on the clients
#
# @param firewall
#   Use the SIMP ``iptables`` module to manage firewall connections
#
# @param stunnel Use the SIMP ``stunnel`` module to manage stunnel
#
# @param tcpwrappers
#   Use the SIMP ``tcpwrappers`` module to manage tcpwrappers
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#

class nfs::server (
#FIXME only have attributes that really need to be here
  Simplib::Netlist      $trusted_nets                  = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1'] }),
  Boolean               $nfsd_vers4                    = true,
  Boolean               $nfsd_vers4_0                  = true,
  Boolean               $nfsd_vers4_1                  = true,
  Boolean               $nfsd_vers4_2                  = true,
  Integer[1]            $sunrpc_udp_slot_table_entries = 128,
  Integer[1]            $sunrpc_tcp_slot_table_entries = 128,
  Boolean               $firewall                      = $::nfs::firewall,
  Boolean               $stunnel                       = $::nfs::stunnel,
  Boolean               $tcpwrappers                   = $::nfs::tcpwrappers,
) inherits ::nfs {

  assert_private()

  include 'nfs::server::config'

  service { 'nfs-server.service':
    ensure     => 'running',
    enable     => true,
    # use the less disruptive reload if possible for a restart
    hasrestart => false,
    restart    => 'systemctl reload-or-restart nfs-server.service',
    hasstatus  => true,
    subscribe  => Class['nfs::server::config']
  }

  if $::nfs::nfsv3
    include 'nfs::service::nfsv3'
    svckill::ignore { 'nfs-mountd': }
  } else {
    ensure_resource('service', 'nfs-mound.service', { ensure => 'masked' })
    ensure_resource('service', 'rpc-statd.service', { ensure => 'masked' })
    ensure_resource('service', 'rpc-statd-notify.service', { ensure => 'masked' })
  }

  if $::nfs::secure_nfs {
    include 'nfs::service::secure'
  } else {
    ensure_resource('service', 'rpc-gssd.service', { ensure => 'masked' })
  }

#FIXME start up rpc.rquotad?
#***rpc-rquotad.service require rpcbind.service
#  RHEL docs says it is started automatically when needed, so, need
#  to configure but not start and thus need svckill?  Other docs show to
#  enable and start the service.  Need to try it and see.
  svckill::ignore('rpc-rquotad.service')

  if $::nfs::idmapd {
    include 'nfs::idmapd::server'
  }


  if $tcpwrappers {
    include 'tcpwrappers'

    tcpwrappers::allow { [
      'mountd',
      # what about sm-modify?
      'statd',
      'rquotad',
      'lockd',
      'rpcbind'
      ]:
      pattern => $trusted_nets
    }
  }

  if $stunnel {
    contain 'nfs::server::stunnel'

    # This is here due to some bug where allowing things through regularly
    # isn't working correctly.
    if $tcpwrappers {
      tcpwrappers::allow { 'nfs': pattern => 'ALL' }
    }
  }


  # $stunnel_port_override is a value that is set by the stunnel overlay.
  if $stunnel and $::nfs::server::stunnel::stunnel_port_override {
    if $firewall {
      include 'iptables'

      iptables::listen::tcp_stateful{ 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
      iptables::listen::udp { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $::nfs::server::stunnel::stunnel_port_override
      }
    }
  }
  else {
    $_rpcbind_port = 111
    if $firewall {
      include 'iptables'
      if $nfsv3 {
        $_ports = [
          $_rpcbind_port,
          $::nfs::nfsd_port,
          $::nfs::rquotad_port,
          $::nfs::lockd_port,
          $::nfs::mountd_port,
          $::nfs::statd_port
        ] # <-- End ports
      } else {
        $_ports = [
          $_rpcbind_port,
          $::nfs::nfsd_port,
          $::nfs::rquotad_port
        ]
      }

      iptables::listen::tcp_stateful { 'nfs_client_tcp_ports':
        trusted_nets => $trusted_nets,
        dports       => $_ports
      }
      #FIXME lockd udp port is likely to be different and is not in the list!
      iptables::listen::udp { 'nfs_client_udp_ports':
        trusted_nets => $trusted_nets,
        dports       => $_ports
      }
    }
  }

}