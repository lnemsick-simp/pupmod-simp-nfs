class nfs::idmapd::client
{
  assert_private()

  if $::nfs::idmapd {
    include 'nfs::idmapd::config'

    # TODO configure /etc/request-key.conf for nfsidmap
  }
}
