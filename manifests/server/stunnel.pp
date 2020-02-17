# Configures a server for NFS over stunnel

# @author https://github.com/simp/pupmod-simp-nfs/graphs/contributors
#
class nfs::server::stunnel {

  assert_private()

  if $nfs::nfsv3 {
    contain 'nfs::server::stunnel::nfsv3and4'
  } else {
    contain 'nfs::server::stunnel::nfsv4'
  }
}
