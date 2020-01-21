# This class provides appropriate service names based on the operating system
#
class nfs::service_names {
  simplib::assert_metadata($module_name)

  # Services here should use the fully qualified service name
  # When Puppet runs `systemctl is-enabled <service>` without `.service`,
  # it doesn't know what to check the enabled status of, and returns
  # unknown
  $nfs_lock    = 'rpc-statd.service'
  $nfs_mountd  = 'nfs-mountd.service'
  $nfs_rquotad = 'nfs-rquotad.service'
  $nfs_server  = 'nfs-server.service'
  $nfs_utils   = 'nfs-utils.service'  # service to be restarted when any config changes
  $rpcidmapd   = 'nfs-idmapd.service'
  $rpcgssd     = 'rpc-gssd.service'
  $gssproxy    = 'gssproxy.service'
  $rpcbind     = 'rpcbind.service'
}
