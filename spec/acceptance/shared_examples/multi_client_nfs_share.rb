# Verify two NFS clients can simultaneously mount the same directory from
# a NFS server
#
#   client1 mount ----> server exported dir
#                       ^
#   client2 mount ------'
#
# This test is most useful for verifying a server supports simultaneous
# stunneled and non-stunneled connections to different clients.
#
# Characteristics of the server capabilities, server exports and clients mounts
# (e.g., stunnel, NFSv4 or NFSv3, insecure export) are controlled by opts.
#
# @param servers Array of Hosts that will only be NFS servers
# @param client1 Host that will only be a NFS client
# @param client2 Host that will only be a NFS client
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata for
#                     all hosts
#  * :server_config - Hash of config to be applied to NFS server
#  * :mount1_config - Hash of config to be applied to NFS client1 for mounts
#                     to a server
#  * :mount2_config - Hash of config to be applied to NFS client2 for mounts
#                     to a server
#

shared_examples 'a multi-client NFS share' do |servers, client1, client2, opts|
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

      file { '#{exported_dir}/#{filename}':

        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => '#{file_content}',
      }

      nfs::server::export { 'nfs_root':
        clients     => ['*'],
        export_path => '/srv/nfs_share',
        sec         => ['#{opts[:server_config][:export_sec]}'],
        insecure    => #{opts[:server_config][:export_insecure].to_s}
      }

      File['#{exported_dir}'] -> Nfs::Server::Export['nfs_root']
    EOM
  }

  servers.each do |server|
    context "with NFS server #{server}" do
      let(:mount_dir) { "/mnt/#{server}" }
      let(:server_ip) {
        info = internal_network_info(server)
        expect(info[:ip]).to_not be_nil
        info[:ip]
      }

      let(:client_manifest_base) {
        <<~EOM
          include 'ssh'

          $mount_dir = '#{mount_dir}'

          nfs::client::mount { $mount_dir:
            nfs_server  => '#{server_ip}',
            remote_path => '#{exported_dir}',
            autofs      => false,
          #MOUNT_OPTIONS#
          }

          # mount directory must exist if not using autofs
          file { $mount_dir:
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
            mode   => '0644'
          }

          File[$mount_dir] -> Nfs::Client::Mount[$mount_dir]
        EOM
      }

      context "as the NFS server #{server}" do
        it 'should ensure vagrant connectivity' do
          on(hosts, 'date')
        end

        it 'should apply server manifest to export' do
          server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
          server_hieradata['nfs::is_client'] = false
          server_hieradata['nfs::is_server'] = true
          set_hieradata_on(server, server_hieradata)
          print_test_config(server_hieradata, server_manifest)
          apply_manifest_on(server, server_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(server, server_manifest, :catch_changes => true)
        end

        it 'should export shared dir' do
          on(server, "exportfs -v | grep #{exported_dir}")
        end
      end

      {
        client1 => opts[:mount1_config],
        client2 => opts[:mount2_config]
      }.each do |client,config|

        context "as NFS client #{client}" do
          let(:client_manifest) {
            client_manifest = client_manifest_base.dup
            client_manifest.gsub!('#MOUNT_OPTIONS#', build_mount_options_old(config))
            client_manifest
          }

          it 'should apply client manifest to mount a dir from the server' do
            client_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
            client_hieradata['nfs::is_client'] = true
            client_hieradata['nfs::is_server'] = false
            set_hieradata_on(client, client_hieradata)
            print_test_config(client_hieradata, client_manifest)
            apply_manifest_on(client, client_manifest, :catch_failures => true)
          end

          it 'should be idempotent' do
            apply_manifest_on(client, client_manifest, :catch_changes => true)
          end

          it "should mount NFS share from #{server}" do
            on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
          end
        end
      end

      context 'test clean up' do
        it 'should remove mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on([client1, client2], %{puppet resource mount #{mount_dir} ensure=absent})
          on([client1, client2], "rm -rf #{mount_dir}")
        end
      end
    end
  end
end
