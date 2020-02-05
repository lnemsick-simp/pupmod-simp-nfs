# @param servers_with_client Array of Hosts each of which will be both an
#   NFS server and NFS client.
#
# @param opts Hash of test options with the following keys:
#  * :autofs     - Whether to use autofs in the client mount
#  * :base_hiera - Base hieradata to be added to nfs-specific hieradata
#  * :nfsv3      - Whether this is testing NFSv3.  When true, NFSv3 will be
#                  enabled (server + client) and used in the client mount
#
shared_examples 'a NFS share with combined roles' do |servers_with_client, opts|
  let(:exported_dir) { '/srv/nfs_share' }
  let(:filename) { 'test_file' }
  let(:file_content) { 'This is a test file' }
  let(:server_manifest) {
    <<~EOM
      include 'ssh'

      file { '#{exported_dir}':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      $exported_file = "#{exported_dir}/#{filename}"
      file { $exported_file:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => '#{file_content}',
      }

      nfs::server::export { 'nfs_root':
        clients     => ['*'],
        export_path => '#{exported_dir}',
        sec         => ['sys']
      }

      File[$exported_file] -> Nfs::Server::Export['nfs_root']
    EOM
  }

  let(:nfs_vers) { opts[:nfsv3] ? 3 : 4 }
  let(:client_manifest_base) {
    <<~EOM
      include 'ssh'

     $autofs = #{opts[:autofs]}
     $mount_dir = '#MOUNT_DIR#'

      nfs::client::mount { $mount_dir:
        nfs_server        => '#SERVER_IP#',
        nfs_vers          => #{nfs_vers},
        remote_path       => '#{exported_dir}',
        autofs            => $autofs
      }

      unless $autofs {
        # mount directory must exist if not using autofs
        file { $mount_dir:
          ensure => 'directory',
          owner  => 'root',
          group  => 'root',
          mode   => '0644'
        }

        File[$mount_dir] -> Nfs::Client::mount[$mount_dir]
      }
    EOM
  }

  servers.each do |server|
    context "as just a NFS server on host #{server}" do
      it 'should apply server manifest to export' do
        server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
        server_hieradata['nfs::is_client'] = false
        server_hieradata['nfs::is_server'] = true
        server_hieradata['nfs::nfsv3'] = opts[:nfsv3]
        set_hieradata_on(server, server_hieradata)
        apply_manifest_on(server, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server, "exportfs | grep #{exported_dir}")
      end
    end
  end

  clients.each do |client|
    context "as just a NFS client on host #{client}" do
      servers.each do |server|
        let(:server_ip) {
          info = internal_network_info(server)
          expect(info[:ip]).to_not be_nil?
          info[:ip]
        }

        let(:mount_dir) { "/mnt/#{server}" }
        let(:client_manifest) {
          client_manifest = client_manifest_base.dup
          client_manifest.gsub!('#MOUNT_DIR#', mount_dir)
          client_manifest.gsub!('#SERVER_IP#', server_ip)
          client_manifest
        }

        it "should apply client manifest to mount dir from #{server}" do
          client_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
          client_hieradata['nfs::is_client'] = true
          client_hieradata['nfs::is_server'] = false
          client_hieradata['nfs::nfsv3'] = opts[:nfsv3]
          set_hieradata_on(client, client_hieradata)

          apply_manifest_on(client, client_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(client, client_manifest, :catch_changes => true)
        end

        it 'should mount NFS share' do
          on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

        it 'mount should be re-established after client reboot' do
          client.reboot
          on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

        it 'mount should be re-established after server reboot' do
          server.reboot
          retry_on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

        it 'should unmount to clean up for follow-on tests' do
          on(client, %{puppet resource mount #{mount_dir} ensure=absent})
        end
      end
    end
  end
end
