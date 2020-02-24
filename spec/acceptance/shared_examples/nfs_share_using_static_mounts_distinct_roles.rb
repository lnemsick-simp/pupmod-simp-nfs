# @param servers Array of Hosts that will only be NFS servers
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the NFS server manifest
#  * :client_custom - Additional content to be added to the NFS client manifest
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server export and
#                     the client mount
#  * :export_insecure - insecure setting for NFS export
#  * :verify_reboot - Whether to verify idempotency and mount functionality
#                     after individually rebooting the client and server
#                     in each test pair
#
# NOTE:  The following token substitutions are supported in the :client_custom
#  manifest:
#
#  * #MOUNT_DIR#
#  * #SERVER_IP#
#
shared_examples 'a NFS share using static mounts with distinct client/server roles' do |servers, clients, opts|
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
        export_path => '#{exported_dir}',
        sec         => ['#{opts[:nfs_sec]}'],
        insecure    => #{opts[:export_insecure]}
      }

      File['#{exported_dir}'] -> Nfs::Server::Export['nfs_root']

      #{opts[:server_custom]}
    EOM
  }

  let(:nfs_version) { opts[:nfsv3] ? 3 : 4 }
  let(:client_manifest_base) {
    <<~EOM
      include 'ssh'

      $mount_dir = '#MOUNT_DIR#'

      nfs::client::mount { $mount_dir:
        nfs_server  => '#SERVER_IP#',
        nfs_version => #{nfs_version},
        remote_path => '#{exported_dir}',
        sec         => '#{opts[:nfs_sec]}',
        autofs      => false
      }

      # mount directory must exist if not using autofs
      file { $mount_dir:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      File[$mount_dir] -> Nfs::Client::Mount[$mount_dir]

      #{opts[:client_custom]}
    EOM
  }

  servers.each do |server|
    context "as just a NFS server #{server}" do
      it 'should ensure vagrant connectivity' do
        on(hosts, 'date')
      end

      it 'should apply server manifest to export' do
        server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
        server_hieradata['nfs::is_client'] = false
        server_hieradata['nfs::is_server'] = true
        server_hieradata['nfs::nfsv3'] = opts[:nfsv3]
        set_hieradata_on(server, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server, 'exportfs -v')
        on(server, "exportfs -v | grep #{exported_dir}")
      end
    end
  end

  clients.each do |client|
    servers.each do |server|
      context "as just a NFS client #{client} using NFS server #{server}" do
        let(:server_ip) {
          info = internal_network_info(server)
          expect(info[:ip]).to_not be_nil
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
          print_test_config(client_hieradata, client_manifest)
          apply_manifest_on(client, client_manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(client, client_manifest, :catch_changes => true)
        end

        it 'should mount NFS share' do
          on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

        if opts[:nfsv3]
          # Want to verify the NLM ports are correctly configured.  According
          # to nfs man page, NLM supports advisory file locks only and the
          # client converts file locks obtained via flock to advisory locks.
          # So, we can use flock in this test.
          #
          # If flock hangs, we have a NLM connectivity problem. Ideally, we would
          # want an immediate indication of a connectivity issues via flock.
          # Unfortunately, even the --nonblock flock option simply hangs when we
          # have communication problem. So, we will timeout to detect communication
          # problems instead.
          it 'should communicate lock status with NFS server' do
            require 'timeout'

            begin
              lock_seconds = 1
              timeout_seconds = lock_seconds + 60
              Timeout::timeout(timeout_seconds) do
                on(client, "date; flock  #{mount_dir}/#{filename} -c 'sleep #{lock_seconds}'; date")
              end
            rescue Timeout::Error
              fail('Problem with NFSv3 connectivity during file lock')
            end
          end
        end

        if opts[:verify_reboot]
          it 'should ensure vagrant connectivity' do
            on(hosts, 'date')
          end

          unless opts[:nfsv3]
            # The nfsv4 kernel module is only automatically loaded when a NFSv4
            # mount is executed. In the NFSv3 test, we only mount using NFSv3.
            # So, after reboot, the nfsv4 kernel module will not be loaded.
            # However, since nfs::client::config pre-emptively loads the nfsv4
            # kernel module (necessary to ensure config initially prior to
            # reboot), applying the client manifest in the absence of NFSv4
            # mount will cause the Exec[modprove_nfsv4] to be executed.
            it 'client manifest should be idempotent after reboot' do
              client.reboot
              apply_manifest_on(client, client_manifest, :catch_changes => true)
            end
          end

          it 'mount should be re-established after client reboot' do
            on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
          end

          it 'server manifest should be idempotent after reboot' do
            server.reboot
            apply_manifest_on(server, server_manifest, :catch_changes => true)
          end

          it 'mount should be re-established after server reboot' do
            on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
          end
        end

        it 'should remove mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on(client, %{puppet resource mount #{mount_dir} ensure=absent})
          on(client, "rm -rf #{mount_dir}")
        end
      end
    end
  end
end
