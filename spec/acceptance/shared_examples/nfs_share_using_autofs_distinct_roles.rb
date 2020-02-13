# @param servers Array of Hosts that will only be NFS servers
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the NFS server manifest
#  * :client_custom - Additional content to be added to the NFS client manifest
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server exports and
#                     the client mounts
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
shared_examples 'a NFS share using autofs with distinct client/server roles' do |servers, clients, opts|
  export_root_path =  '/srv/nfs_root'
  mount_root_path = '/mnt'
  mount_map = {
     :direct            => {
       :export_dir     => "#{export_root_path}/for_direct",
       :exported_files => [ "#{export_root_path}/for_direct/test_file" ],
       :mount_name     => "#{mount_root_path}/direct",
       :mounted_files  => [ "#{mount_root_path}/direct/test_file" ]
     },
     :indirect          => {
       :export_dir     => "#{export_root_path}/for_indirect",
       :exported_files => [ "#{export_root_path}/for_indirect/test_file" ],
       :mount_name     => "#{mount_root_path}/indirect",
       :mounted_files  => [ "#{mount_root_path}/indirect/autodir/test_file" ],
       :map_key        => 'autodir',
       :add_key_subst  => false,
     },
     :indirect_wildcard => {
       :export_dir     => "#{export_root_path}/for_indirect_wildcard",
       :exported_files => [
         "#{export_root_path}/for_indirect_wildcard/sub1/test_file",
         "#{export_root_path}/for_indirect_wildcard/sub2/test_file"
       ],
       :mount_name     => "#{mount_root_path}/indirect_wildcard",
       :mounted_files  => [
         "#{mount_root_path}/indirect_wildcard/sub1/test_file",
         "#{mount_root_path}/indirect_wildcard/sub2/test_file"
       ],
       :map_key       => '*',
       :add_key_subst => true,
    }
  }

  let(:export_dirs) { mount_map.map { |type,info| info[:export_dir] }.flatten }
  let(:exported_files) { mount_map.map { |type,info| info[:exported_files] }.flatten }
  let(:mounted_files) { mount_map.map { |type,info| info[:mounted_files] }.flatten }
  let(:file_content_base) { 'This is a test file from' }
  let(:server_manifest) {
    <<~EOM
      include 'ssh'

      file { '#{export_root_path}':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      $export_dirs = [
        '#{export_dirs.join("',\n  '")}'
      ]

      $export_dirs.each |String $_export_dir| {
        file { $_export_dir:
          ensure => 'directory',
          owner  => 'root',
          group  => 'root',
          mode   => '0644'
        }

        nfs::server::export { $_export_dir:
          clients     => ['*'],
          export_path => $_export_dir,
          sec         => ['sys']
        }

        File["${_export_dir}"] -> Nfs::Server::Export["${_export_dir}"]
      }

      $files = [
        '#{exported_files.join("',\n  '")}'
      ]

      $dir_attr = {
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      $files.each |String $_file| {
        $_path = dirname($_file)
        ensure_resource('file', $_path, $dir_attr)

        file { $_file:
          ensure  => 'file',
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => "#{file_content_base} ${_path}",
        }
      }

      #{opts[:server_custom]}
    EOM
  }

  let(:nfs_version) { opts[:nfsv3] ? 3 : 4 }
  let(:client_manifest_base) {
    <<~EOM
      include 'ssh'

      $mount_root_dir = '#MOUNT_ROOT_DIR#'

      # direct mount
      nfs::client::mount { '#{mount_map[:direct][:mount_name]}':
        nfs_server  => '#SERVER_IP#',
        nfs_version => #{nfs_version},
        remote_path => '#{mount_map[:direct][:export_dir]}',
        autofs      => true,
      }

      # indirect mount
      nfs::client::mount { '#{mount_map[:indirect][:mount_name]}':
        nfs_server              => '#SERVER_IP#',
        nfs_version             => #{nfs_version},
        remote_path             => '#{mount_map[:indirect][:export_dir]}',
        autofs                  => true,
        autofs_indirect_map_key => '#{mount_map[:indirect][:map_key]}',
        autofs_add_key_subst    => #{mount_map[:indirect][:add_key_subst].to_s}
      }

      # indirect mount with wildcard and map key substitution
      nfs::client::mount { '#{mount_map[:indirect_wildcard][:mount_name]}':
        nfs_server              => '#SERVER_IP#',
        nfs_version             => #{nfs_version},
        remote_path             => '#{mount_map[:indirect_wildcard][:export_dir]}',
        autofs                  => true,
        autofs_indirect_map_key => '#{mount_map[:indirect_wildcard][:map_key]}',
        autofs_add_key_subst    => #{mount_map[:indirect_wildcard][:add_key_subst].to_s}
      }

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
        apply_manifest_on(server, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server, server_manifest, :catch_changes => true)
      end

      it 'should export shared dirs' do
        export_dirs.each do |dir|
          on(server, "exportfs | grep -w #{dir}")
        end

        on(server, "find #{export_root_path} -type f | sort")
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
          client_manifest.gsub!('#MOUNT_ROOT_DIR#', mount_dir)
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

        it 'should automount NFS shares' do
          mounted_files.each do |file|
            auto_dir = File.dirname(file)
            filename = File.basename(file)
            on(client, %(cd #{auto_dir}; grep '#{file_content_base}' #{filename}))
          end

          on(client, "find #{mount_root_path} -type f | sort")
        end

        if opts[:verify_reboot]
          it 'should ensure vagrant connectivity' do
            on(hosts, 'date')
          end

          it 'automount should be valid after client reboot' do
            client.reboot
            mounted_files.each do |file|
              auto_dir = File.dirname(file)
              filename = File.basename(file)
              on(client, %(cd #{auto_dir}; grep '#{file_content_base}' #{filename}))
            end

            on(client, "find #{mount_root_path} -type f | sort")
          end

          it 'automount should be valid after server reboot' do
            server.reboot
            mounted_files.each do |file|
              auto_dir = File.dirname(file)
              filename = File.basename(file)
              on(client, %(cd #{auto_dir}; grep '#{file_content_base}' #{filename}))
            end

            on(client, "find #{mount_root_path} -type f | sort")
          end
        end

        it 'should stop and disable autofs service as prep for next test' do
          # auto-mounted filesystems are unmounted when autofs service is stopped
          on(client, %{puppet resource service autofs ensure=stopped enable=false})
        end
      end
    end
  end
end
