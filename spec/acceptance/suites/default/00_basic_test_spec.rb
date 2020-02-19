require 'spec_helper_acceptance'

test_name 'nfs basic'

describe 'nfs basic' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  servers_with_client = hosts_with_role( hosts, 'nfs_server_and_client' )
  servers_tcpwrappers = servers.select { |server| server.name.match(/el7/) }

  clients = hosts_with_role( hosts, 'nfs_client' )
  clients_tcpwrappers = clients.select { |client| client.name.match(/el7/) }

  base_hiera = {
    # Set us up for a basic NFS (firewall-only)
    'simp_options::firewall'                => true,
    'simp_options::kerberos'                => false,
    'simp_options::stunnel'                 => false,
    'simp_options::tcpwrappers'             => false,
    'ssh::server::conf::permitrootlogin'    => true,
    'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',

    # assuming all hosts configured to have same networks (public and private)
    'simp_options::trusted_nets'            => host_networks(hosts[0]),
  }

  context 'configure firewalld to use iptables backend' do
    # FIXME. Temporary workaround until can configure via firewalld module
    hosts.each do |host|
      if host.hostname.start_with?('el8')
        on(host, "sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf")
      end
    end
  end

  context 'with firewall only' do
    context 'NFSv4 with firewall' do
      opts = {
        :base_hiera      => base_hiera,
        :export_insecure => false,
        :nfs_sec         => 'sys',
        :nfsv3           => false,
        :verify_reboot   => true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end

    context 'NFSv3 with firewall' do
      opts = {
        :base_hiera      => base_hiera,
        :export_insecure => false,
        :nfs_sec         => 'sys',
        :nfsv3           => true,
        :verify_rebootbb => true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end
  end

  context 'with firewall and tcpwrappers' do
    context 'NFSv4 with firewall and tcpwrappers' do
      opts = {
        :base_hiera      => base_hiera.merge( {'simp_options::tcpwrappers' => true } ),
        :export_insecure => false,
        :nfs_sec         => 'sys',
        :nfsv3           => false,
        :verify_reboot   => false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts

      it_behaves_like 'a NFS share using autofs with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts
    end

    context 'NFSv3 with firewall and tcpwrappers' do
      opts = {
        :base_hiera      => base_hiera.merge( {'simp_options::tcpwrappers' => true } ),
        :export_insecure => false,
        :nfs_sec         => 'sys',
        :nfsv3           => true,
        :verify_reboot   => false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts

      it_behaves_like 'a NFS share using autofs with distinct client/server roles',
        servers_tcpwrappers, clients_tcpwrappers, opts
    end
  end
end
