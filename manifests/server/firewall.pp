
class nfs::server::firewall
{
  assert_private()

  if $::nfs::server::stunnel {
    include 'nfs::server::firewall::stunnel'
  } elsif $::nfs::nfsv3 {
    include 'nfs::server::firewall::nfsv3'
  } else {
    include 'nfs::server::firewall::nfsv4'
  }
}
