require 'spec_helper_acceptance'

test_name 'nfs basic'

describe 'nfs basic' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  servers_with_client = hosts_with_role( hosts, 'nfs_server_and_client' )
  clients = hosts_with_role( hosts, 'nfs_client' )
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
# TEMPORARY WORKAROUND
    hosts.each do |host|
      if host.hostname.start_with?('el8')
        on(host, "sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf")
      end
    end
  end

  context 'with firewall only' do
    context 'NFSv4' do
      opts = {
        :base_hiera    => base_hiera,
        :krb5          => false,
        :nfsv3         => false,
        :verify_reboot => true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end

    context 'NFSv3' do
      opts = {
        :base_hiera    => base_hiera,
        :krb5          => false,
        :nfsv3         => true,
        :verify_reboot => true
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using static mounts with combined client/server roles', servers_with_client, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end
  end

  context 'with firewall and tcpwrappers' do
    context 'NFSv4' do
      opts = {
        :base_hiera    => base_hiera.merge( {'simp_options::tcpwrappers' => true } ),
        :krb5          => false,
        :nfsv3         => false,
        :verify_reboot => false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end

    context 'NFSv3' do
      opts = {
        :base_hiera    => base_hiera.merge( {'simp_options::tcpwrappers' => true } ),
        :krb5          => false,
        :nfsv3         => true,
        :verify_reboot => false
      }

      it_behaves_like 'a NFS share using static mounts with distinct client/server roles', servers, clients, opts
      it_behaves_like 'a NFS share using autofs with distinct client/server roles', servers, clients, opts
    end
  end
=begin

  context 'server changes' do
    servers.each do |server|
      it 'should restart all services correctly when configuration changes' do
      end

      it 'should start all NFS services when all have been killed' do
        on(server, 'systemctl stop nfs-server')
      end

      it 'should start missing NFS services some have been killed' do
      end
    end
  end
# for lock
# SEC=10;for ((i=SEC;i>=0;i--));do echo -ne "\r$(date -d"0+$i sec" +%H:%M:%S)";sleep 1;done
# flock test_file -c 'SEC=10;for ((i=SEC;i>=0;i--));do echo -ne "\r$(date -d"0+$i sec" +%H:%M:%S)";sleep 1;done'

=end
end
