class nfs::idmapd::client
{
  assert_private()

  include 'nfs::idmapd::config'

  # FIXME configure /etc/request-key.conf for nfsidmap
}
