
class nfs::server::firewall
{
  assert_private()

  if $::nfs::server::stunnel {
    contain 'nfs::server::firewall::stunnel'
  } elsif $::nfs::nfsv3 {
    contain 'nfs::server::firewall::nfsv3'
  } else {
    contain 'nfs::server::firewall::nfsv4'
  }
}
