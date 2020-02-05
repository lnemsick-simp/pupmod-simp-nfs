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

  context 'NFSv4 without autofs' do
    opts = {
      :autofs     => false,
      :base_hiera => base_hiera,
      :nfsv3      => false
    }

    it_behaves_like 'a NFS share with distinct roles', servers, clients, opts
#    it_behaves_like 'a NFS share with combined roles', servers_with_client, opts
  end

  context 'NFSv3 without autofs' do
    opts = {
      :autofs     => false,
      :base_hiera => base_hiera,
      :nfsv3      => true
    }

    it_behaves_like 'a NFS share with distinct roles', servers, clients, opts
#    it_behaves_like 'a NFS share with combined roles', servers_with_client, opts
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
