# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# A helper for setting up the cross-system connectivity parts of a mount
#
# **This should NOT be called from outside ``nfs::client::mount``**
#
# All parameters map to their counterparts in ``nfs::client::mount``
#
# @param nfs_server
# @param nfs_version
# @param nfs_port
# @param v4_remote_port
# @param stunnel
# @param stunnel_wantedby
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define nfs::client::mount::connection (
  Simplib::Ip             $nfs_server,
  Integer[3,4]            $nfs_version,
  Optional[Integer[0]]    $nfs_minor_version = undef,
  Simplib::Port           $nfs_port          = 2049,
  Optional[Simplib::Port] $v4_remote_port    = undef,
  Optional[Boolean]       $stunnel           = undef,
  Array[String]           $stunnel_wantedby  = []
) {

  # This is only meant to be called from inside nfs::client::mount
  assert_private()

  # Take our best shot at getting this right...
  # If this doesn't work, you'll need to set ``stunnel`` to ``false`` in your
  # call to ``nfs::client::mount``
  if $stunnel {
    if $nfs_version == 3 {
      # This is not great but the target is actually only able to be called
      # once anyway
      ensure_resource('class',
        'nfs::client::stunnel',
        {
          nfs_server => $nfs_server
        }
      )
    }
    else {
      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('nfs::client::stunnel::v4',
        "${nfs_server}:${nfs_port}",
        {
          nfs_connect_port     => $v4_remote_port,
          stunnel_wantedby     => $stunnel_wantedby,
        }
      )
    }
  }

  # Set up the NFSv4.0 delegation callback port IPTables opening.  This is only
  # needed for NFSv4.0, because, beginning with NFSv4.1 delegation does not
  # require a side channel.
  #
  if $nfs::client::firewall  {
    include 'iptables'

    # WORK AROUND iptables::listen::xxx issue with invalid firewalld services
    # filenames caused by rules with IP addresses
    $_safe_nfs_server = regsubst($nfs_server, '[\.:]', '_', 'G')

    if ($nfs_version == 4) {

      # It is possible that this is called for multiple mounts on the same server
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_callback_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => $nfs::client::callback_port
        }
      )
    } else {
      # NFS server will reach out to the client in NLM and NSM protos
      # (i.e., locking and recovery from locking upon server/client reboot)
      # and uses rpcbind to figure out ports to use on the client
      $_rpcbind_port = 111
      ensure_resource('iptables::listen::tcp_stateful',
        "nfs_status_tcp_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => [$_rpcbind_port, $nfs::lockd_port, $nfs::statd_port]
        }
      )

      ensure_resource('iptables::listen::udp',
        "nfs_status_udp_${_safe_nfs_server}",
        {
          trusted_nets => [$nfs_server],
          dports       => [$_rpcbind_port, $nfs::lockd_udp_port, $nfs::statd_port]
        }
      )
    }
  }
}
