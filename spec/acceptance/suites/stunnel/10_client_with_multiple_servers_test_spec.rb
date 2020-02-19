require 'spec_helper_acceptance'

test_name 'nfs client with multiple servers'

#################################################################
# IMPORTANT:  See discussion of nfs::server::export::insecure in
# 00_stunnel_test_spec.rb.
#################################################################

# Tests stunneling between an individual NFS client and 2 NFS server
describe 'nfs client with multiple servers' do

  servers = hosts_with_role( hosts, 'nfs_server' )

  # Setting up distinct ports for NFSv3 is painful. So, in this test
  # we are going to only handle two servers.
  if servers.size < 2
    fail("#{__FILE__} requires at least 2 hosts with role 'nfs_server'")
  end

  server1 = servers[0]
  server2 = servers[1]
  clients = hosts_with_role( hosts, 'nfs_client' )

  base_hiera = {
    # Set us up for a stunneled NFS with firewall
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
    # This is replicated so can run this test by itself.
    hosts.each do |host|
      if host.hostname.start_with?('el8')
        on(host, "sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf")
      end
    end
  end

  context 'client mounting from 2 NFSv4 servers' do
    opts = {
      :base_hiera      => base_hiera,
      :export_insecure => true,
      :nfs_sec         => 'sys',
      :nfsv3           => false,
      :verify_reboot   => true,

      # Overrides cannot match defaults.
      :port_overrides => {
        :nfsd_port            => 2149,  # default=2049
        :rquotad_port         => 876,   # default=875
        :stunnel_nfsd_port    => 21480, # default=20490
        :stunnel_rquotad_port => 8760,  # default=8750
      }
    }

    it_behaves_like 'a multi-server NFS share',
      server1, server2, clients, opts
  end

  context 'client mounting from 2 NFSv3 servers' do
    opts = {
      :base_hiera      => base_hiera,
      :export_insecure => true,
      :nfs_sec         => 'sys',
      :nfsv3           => true,
      :verify_reboot   => true,

      # Overrides cannot match defaults.  In addition, lockd_port and statd_port
      # cannot match either of their correspoding server and client defaults.
      :port_overrides => {
        :lockd_port_server    => 32813, # client default=32802, server default=32803
        :mountd_port          => 21048, # default=20048
        :nfsd_port            => 2149,  # default=2049
        :rquotad_port         => 876,   # default=875
        :statd_port_server    => 663,   # client default=661, server default=662
        :stunnel_lockd_port   => 32814, # default 32804
        :stunnel_mountd_port  => 8921,  # default=8920
        :stunnel_nfsd_port    => 21490, # default=20490
        :stunnel_rquotad_port => 8760,  # default=8750
        :stunnel_statd_port   => 6630,  # default=6620
      }
    }

    it_behaves_like 'a multi-server NFS share',
      server1, server2, clients, opts
  end
end
