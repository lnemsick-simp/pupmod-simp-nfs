require 'spec_helper_acceptance'

test_name 'nfs basic NFSv4'

describe 'nfs basic NFSv4' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )

  let(:basic_manifest) {
    <<~EOM
      include 'nfs'
      include 'ssh'
    EOM
  }

  let(:server_manifest) {
    <<~EOM
      include 'nfs'
      include 'ssh'

      file { '/srv/nfs_share':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      file { '/srv/nfs_share/test_file':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => 'This is a test'
      }

      nfs::server::export { 'nfs4_root':
        clients     => ['*'],
        export_path => '/srv/nfs_share',
        sec         => ['sys']
      }

      File['/srv/nfs_share'] -> Nfs::Server::Export['nfs4_root']
    EOM
  }

  let(:hieradata) {
    <<~EOM
---
# Set us up for a basic NFSv4 server for right now (no Kerberos)
simp_options::firewall : true
simp_options::kerberos : false
simp_options::stunnel : false
simp_options::tcpwrappers : false
simp_options::trusted_nets : ['ALL','0.0.0.0/0']

ssh::server::conf::permitrootlogin : true
ssh::server::conf::authorizedkeysfile : '.ssh/authorized_keys'

nfs::is_server: #IS_SERVER#
    EOM
  }

  context 'setup' do
    hosts.each do |host|
      it 'should work with no errors' do
        hdata = hieradata.dup
        if servers.include?(host)
          hdata.gsub!(/#NFS_SERVER#/m, fact_on(host, 'fqdn'))
          hdata.gsub!(/#IS_SERVER#/m, 'true')
        else
          hdata.gsub!(/#NFS_SERVER#/m, servers.last.to_s)
          hdata.gsub!(/#IS_SERVER#/m, 'false')
        end

        set_hieradata_on(host, hdata)
        apply_manifest_on(host, basic_manifest, :catch_failures => true)
      end

      it 'should converge in 1 extra puppet run' do
        # sysctl resource loads all kernel parameter/value pairs once
        # at the beginning of the catalog.  We have logic that will
        # load a kernel module and then set the kernel parameters
        # using a sysctl resource.  So, the syctl resource setting
        # will not work the first time because of old, cached info.
        apply_manifest_on(host, basic_manifest, :catch_failures => true)
        apply_manifest_on(host, basic_manifest, :catch_changes => true)
      end
    end
  end

  context 'as a server' do
    servers.each do |server|
      it 'should export a directory' do
        apply_manifest_on(server, server_manifest, :catch_failures => true)
      end
    end
  end

  context 'as a client' do
    clients.each do |client|
      servers.each do |server|
        it "should mount a directory on the #{server} server" do
          server_fqdn = fact_on(server, 'fqdn')

          client_manifest = <<-EOM
            include 'ssh'

            nfs::client::mount { '/mnt/#{server}':
              nfs_server        => '#{server_fqdn}',
              remote_path       => '/srv/nfs_share',
              autodetect_remote => #{!servers.include?(client)},
              autofs            => false
            }
          EOM

          if servers.include?(client)
            client_manifest = client_manifest + "\n" + server_manifest
          end

          client.mkdir_p("/mnt/#{server}")
          apply_manifest_on(client, client_manifest, :catch_failures => true)
          on(client, %(grep -q 'This is a test' /mnt/#{server}/test_file))
        end

        it 'mount should be re-established after client reboot' do
          client.reboot
          retry_on(client, %(grep -q 'This is a test' /mnt/#{server}/test_file))
        end

        it 'mount should be re-established after server reboot' do
          unless client == server
            server.reboot
            retry_on(client, %(grep -q 'This is a test' /mnt/#{server}/test_file))
          end
        end

        it 'should restart all services correctly when configuration changes' do
        end

        it 'manifest should start all NFS services when all have been killed' do
        end

        it 'manifest should start missing NFS services some have been killed' do
        end

        it 'should unmount to clean up for follow-on tests' do
          on(client, %{puppet resource mount /mnt/#{server} ensure=absent})
        end
      end
    end
  end
end
