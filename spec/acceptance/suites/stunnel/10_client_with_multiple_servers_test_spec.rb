require 'spec_helper_acceptance'

test_name 'nfs client with multiple servers'

#################################################################
# IMPORTANT:  See discussion of nfs::server::export::insecure in
# 00_stunnel_test_spec.rb.
#################################################################

# Tests stunneling between an individual NFS client and 2 NFS server.
# Verifies client can support a mix of NFSv4 (stunneled) and NFSv3 (direct)
# mount.
describe 'nfs client with multiple servers' do

  servers = hosts_with_role( hosts, 'nfs_server' )

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
    # will only apply to NFSv4 connections
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

  context 'client mounting from 2 NFSv4 servers, both via stunnel' do
    opts = {
      :base_hiera      => base_hiera,
      :mount1_config   => {
        :export_insecure   => true,  # server allows mount via NFSv4 stunnel
        :nfsv3             => false, # server NFSv4, client mount NFSv4
        :nfs_sec           => 'sys',
        :nfsd_port         => nil,   # server & client use default of 2049
        :stunnel_nfsd_port => nil,   # server & client use default of 20490
        :mount_stunnel     => nil    # use simp_options::stunnel default, true
      },
      :mount2_config   => {
        :export_insecure   => true,  # server allows mount via NFSv4 stunnel
        :nfsv3             => false, # server NFSv4, client mount NFSv4
        :nfs_sec           => 'sys',
        :nfsd_port         => 2150,  # server & client, avoid port conflicts with server1
        :stunnel_nfsd_port => 21500, # server & client, avoid port conflicts with server1
        :mount_stunnel     => nil    # use simp_options::stunnel default, true
      },
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end

  context 'client mounting from 1 NFSv4 server via stunnel and 1 NFSv3 server directly' do
    opts = {
      :base_hiera      => base_hiera,
      :mount1_config   => {
        :export_insecure   => true,  # server allows mount via NFSv4 stunnel
        :nfsv3             => false, # server NFSv4, client mount NFSv4
        :nfs_sec           => 'sys',
        :nfsd_port         => nil,   # server & client use default=2049
        :stunnel_nfsd_port => nil,   # server & client use default of 20490
        :mount_stunnel     => nil    # use simp_options::stunnel default, true
      },
      :mount2_config   => {
        :export_insecure   => true,  # server allows mount via NFSv4 stunnel
        :nfsv3             => true,  # server NFSv3 and NFSv4, client mount NFSv3
        :nfs_sec           => 'sys',
        :nfsd_port         => 2150,  # server & client; avoid port conflicts with server1
        :stunnel_nfsd_port => 21500, # unused in non-tunneled mount
        :mount_stunnel     => false
      }
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end

  context 'client mounting from 2 NFSv3 servers directly' do
    opts = {
      :base_hiera      => base_hiera,
      :mount1_config   => {
        :export_insecure   => true, # server allows mount via NFSv4 stunnel
        :nfsv3             => true, # server NFSv3 and NFSv4, client mount NFSv3
        :nfs_sec           => 'sys',
        :nfsd_port         => nil,   # server & client use default=2049
        :stunnel_nfsd_port => nil,   # unused in non-tunneled mount
        :mount_stunnel     => false
      },
      :mount2_config   => {
        :export_insecure   => true, # server allows mount via NFSv4 stunnel
        :nfsv3             => true, # server NFSv3 and NFSv4, client mount NFSv3
        :nfs_sec           => 'sys',
        :nfsd_port         => 2150,  # server & client avoid port conflicts with server1
        :stunnel_nfsd_port => 21500, # unused in non-tunneled mount
        :mount_stunnel     => false
      }
    }

    it_behaves_like 'a multi-server NFS share', server1, server2, clients, opts
  end
end
