# Configures a server for NFS over stunnel

# @param verify
#   The verification level that should be done on the clients
#
#   * See ``stunnel::instance::verify`` for details
#
# @param trusted_nets
#   The systems that are allowed to connect to this service
#
#   * Set to 'any' or 'ALL' to allow the world
#
# @param nfs_accept_address
#   The address upon which the NFS server will listen
#
#   * You should be set this to ``0.0.0.0`` for all interfaces
#
# @param nfs_accept_port
#   Stunnel listening port mapped to the nfsd listening port
#
# @param nlockmgr_accept_port
#   Stunnel listening port mapped to the NFSv3 lockd listening port
#
# @param mountd_accept_port
#   Stunnel listening port mapped to the NFSv3 nfs-mountd service listening port
#
# @param status_accept_port
#   Stunnel listening port mapped to the NFSv3 rpc-statd service listening port
#
# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::stunnel (
#FIXME move these params to nfs::server
  Integer          $verify                 = 2,
  Simplib::Netlist $trusted_nets           = $nfs::server::trusted_nets,
  Simplib::IP      $nfs_accept_address     = '0.0.0.0',
  Simplib::Port    $nfs_accept_port        = 20490,
  Simplib::Port    $nlockmgr_accept_port   = 32804,
  Simplib::Port    $mountd_accept_port     = 8920,
  Simplib::Port    $status_accept_port     = 6620,
  Array[String]    $stunnel_wantedby       = $nfs::server::stunnel_wantedby,
  Boolean          $firewall               = $nfs::server::firewall,
  Boolean          $tcpwrappers            = $nfs::server::tcpwrappers
) {

  assert_private()

  if $nfs::nfsv3 {
    contain 'nfs::server::stunnel::nfsv3and4'
  } else {
    contain 'nfs::server::stunnel::nfsv4'
  }
}
