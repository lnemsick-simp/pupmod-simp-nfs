require 'spec_helper_acceptance'

test_name 'nfs stunnel'

################################################################################
# IMPORTANT:
# The exports in this test set nfs::server::export::insecure to true because of
# a bug in NFS.  When more than one rule in /etc/exports can be mapped to a
# client IP address and at least one of the rules has 'insecure' set to false
# (the default setting), that rule will be selected, EVEN IF it is less
# specific than the rule with 'insecure' set to true.  This impacts stunnel
# because stunnel uses non-privileged ports to communicate locally with the
# NFS daemons.
#
# Specifically, consider the following:
#   nfs::server::export { 'my_share':
#     clients     => ['*'],  # we're protected by a firewall, so wildcard is OK
#     export_path => '/srv/my_share'
#   }
#
# This will generate two rules in /etc/exports:
#   /srv/my_share *(sync,security_label,sec=sys,anonuid=65534,anongid=65534)
#   /srv/my_share 127.0.0.1(sync,security_label,sec=sys,anonuid=65534,anongid=65534,insecure)
#
# When a NFS client attempts to mount /srv/my_share via stunnel, the request
# will pass through the tunnel and be translated in a request from
# 127.0.0.1:<non-privileged port>.  NFS then selects the wildcard rule as the
# best match. However, because secure ports are disallowed by that rule, the
# mount will fail.
################################################################################


# Tests stunneling between individual NFS client and NFS server pairs
describe 'nfs stunnel' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  servers_with_client = hosts_with_role( hosts, 'nfs_server_and_client' )
  servers_tcpwrappers = servers.select { |server| server.name.match(/el7/) }

  clients = hosts_with_role( hosts, 'nfs_client' )
  clients_tcpwrappers = clients.select { |client| client.name.match(/el7/) }

  base_hiera = {
    # Set us up for a basic stunneled NFS (firewall-only)
    'simp_options::audit'                   => false,
    'simp_options::firewall'                => true,
    'simp_options::haveged'                 => true,
    'simp_options::kerberos'                => false,
    'simp_options::pki'                     => true,
    'simp_options::pki::source'             => '/etc/pki/simp-testing/pki',
    'simp_options::stunnel'                 => true,
    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),

    # There is no DNS so we need to eliminate verification
    'nfs::stunnel_verify'                   => 0,
  }

  context 'configure firewalld to use iptables backend' do
    # FIXME. Temporary workaround until can configure via firewalld module
    hosts.each do |host|
      if host.hostname.start_with?('el8')
        on(host, "sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf")
      end
    end
  end

  context 'with NFSv4 stunnel and firewall' do
    opts = {
      :base_hiera              => base_hiera,
      :export_insecure         => true,
      :nfs_sec                 => 'sys',
      :nfsv3                   => false,
      :mount_autodetect_remote => [ false ],
      :verify_reboot           => true
    }

    it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
    it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
    it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
  end

  context 'with NFSv4 stunnel, firewall and tcpwrappers' do
    opts = {
      :base_hiera      => base_hiera.merge( {'simp_options::tcpwrappers' => true } ),
      :export_insecure => true,
      :nfs_sec         => 'sys',
      :nfsv3           => false,
      :verify_reboot   => false
    }

    it_behaves_like 'a NFS share using static mounts with distinct client/server roles',
      servers_tcpwrappers, clients_tcpwrappers, opts

    it_behaves_like 'a NFS share using autofs with distinct client/server roles',
      servers_tcpwrappers, clients_tcpwrappers, opts
  end
end
