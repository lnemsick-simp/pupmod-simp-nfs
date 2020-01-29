require 'spec_helper_acceptance'

test_name 'nfs basic NFSv4 with autofs'

describe 'nfs basic NFSv4 with autofs' do

  servers = hosts_with_role( hosts, 'nfs_server' )
  clients = hosts_with_role( hosts, 'client' )

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

  context 'as a client' do
    clients.each do |client|
      servers.each do |server|
#FIXME use client mount specification that will work
        it "should mount a directory on the #{server} server with autofs" do
          server_fqdn = fact_on(server, 'fqdn')

          autofs_client_manifest = <<-EOM
            include 'ssh'

            nfs::client::mount { '/mnt/#{server}':
              nfs_server        => '#{server_fqdn}',
              remote_path       => '/srv/nfs_share',
              autodetect_remote => #{!servers.include?(client)},
              autofs            => true
            }
          EOM

          if servers.include?(client)
            autofs_client_manifest = autofs_client_manifest + "\n" + server_manifest
          end

          apply_manifest_on(client, autofs_client_manifest, catch_failures: true)
          apply_manifest_on(client, autofs_client_manifest, catch_changes: true)
          # FIXME:  SIMP-2944
          # We are **NOT** checking a file on the automounted directory, because it
          # is not set up correctly
          # on(client, %(cd /mnt/#{server}; grep -q 'This is a test' test_file))
        end

        it 'should unmount to clean up for follow-on tests' do
          on(client, %{puppet resource service autofs ensure=stopped})
        end
      end
    end
  end
end
