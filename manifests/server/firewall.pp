
class nfs::server::firewall
{

  assert_private()

  include 'iptables'

  if $::nfs::server::stunnel {
    if $::nfs::nfsv3 {
      include 'nfs::server::firewall::nfsv3_stunnel'
    } else {
      include 'nfs::server::firewall::nfsv4_stunnel'
    }
  } elsif $::nfs::nfsv3 {
    include 'nfs::server::firewall::nfsv3'
  } else {
    include 'nfs::server::firewall::nfsv4'
  }
}
