# @summary NFS server firewall configuration
class nfs::server::firewall
{
  assert_private()

  if $nfs::server::stunnel {
    # NFSv4 stunnel will take care of opening the firewall for its port

    if $nfs::nfsv3 {
      contain 'nfs::server::firewall::nfsv3and4'
    }
  } elsif $nfs::nfsv3 {
    contain 'nfs::server::firewall::nfsv3and4'
  } else {
    contain 'nfs::server::firewall::nfsv4'
  }
}
