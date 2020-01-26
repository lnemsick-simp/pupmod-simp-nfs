# This class provides appropriate service names based on the operating system
#
class nfs::service_names {
  simplib::assert_metadata($module_name)

  # Services here should use the fully qualified service name
  # When Puppet runs `systemctl is-enabled <service>` without `.service`,
  # it doesn't know what to check the enabled status of, and returns
  # unknown
  $rpc_statd_notify = 'rpc-statd-notify.service '
  $nfs_mountd       = 'nfs-mountd.service'
  $nfs_rquotad      = 'rpc-rquotad.service'
  $nfs_client       = 'nfs-client.target'
  $nfs_server       = 'nfs-server.service'
  $rpcidmapd        = 'nfs-idmapd.service'
  $rpcgssd          = 'rpc-gssd.service'
  $gssproxy         = 'gssproxy.service'
  $rpcbind          = 'rpcbind.service'
}
