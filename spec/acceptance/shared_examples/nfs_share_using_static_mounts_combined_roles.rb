# @param servers_with_client Array of Hosts each of which will be both an
#   NFS server and NFS client.
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the combined manifest
#  * :client_custom - Additional content to be added to the combined manifest
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server exports and
#                     the client mounts
#  * :export_insecure - insecure setting for NFS export
#  * :mount_autodetect_remote - Array of nfs::client::mount::autodetect_remote
#                     values to test
#
# NOTE:  The following token substitutions are supported in the :server_custom
#  and :client_custom manifests:
#
#  * #MOUNT_DIR#
#  * #SERVER_IP#
#  * #AUTODETECT_REMOTE#
#
shared_examples 'a NFS share using static mounts with combined client/server roles' do |servers_with_client, opts|
  let(:exported_dir) { '/srv/nfs_share' }
  let(:filename) { 'test_file' }
  let(:file_content) { 'This is a test file' }
  let(:manifest_base) {
    <<~EOM
      include 'ssh'

      # NFS server portion
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
        sec         => ['#{opts[:nfs_sec]}'],
        insecure    => #{opts[:export_insecure]}
      }

      File[$exported_file] -> Nfs::Server::Export['nfs_root']

      #{opts[:server_custom]}

      # NFS client portion
      $mount_dir = '#MOUNT_DIR#'

      nfs::client::mount { $mount_dir:
        nfs_server        => '#SERVER_IP#',
        nfs_version       => #{nfs_vers},
        remote_path       => '#{exported_dir}',
        sec               => '#{opts[:nfs_sec]}',
        autodetect_remote => #AUTODETECT_REMOTE#,
        autofs            => false
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

      Nfs::Server::Export['nfs_root'] -> Nfs::Client::Mount[$mount_dir]
    EOM
  }

  let(:nfs_vers) { opts[:nfsv3] ? 3 : 4 }

  servers_with_client.each do |host|
    opts[:mount_autodetect_remote].each do |autodetect_remote|
      let(:mount_dir) { "/mnt/#{host}" }
      let(:server_ip) {
        info = internal_network_info(host)
        expect(info[:ip]).to_not be_nil
        info[:ip]
      }

      context "with autodetect_remote=#{autodetect_remote} on host #{host}" do
        let(:manifest) {
          manifest = manifest_base.dup
          manifest.gsub!('#MOUNT_DIR#', mount_dir)
          manifest.gsub!('#SERVER_IP#', server_ip)
          manifest.gsub!('#AUTODETECT_REMOTE#', autodetect_remote.to_s)
          manifest
        }

        it 'should ensure vagrant connectivity' do
          on(hosts, 'date')
        end

        it 'should apply server+client manifest to export+mount' do
          hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
          hieradata['nfs::is_client'] = true
          hieradata['nfs::is_server'] = true
          hieradata['nfs::nfsv3'] = opts[:nfsv3]
          set_hieradata_on(host, hieradata)
          print_test_config(hieradata, manifest)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, :catch_changes => true)
        end

        it 'should export shared dir' do
          on(host, 'exportfs -v')
          on(host, "exportfs | grep #{exported_dir}")
        end

        it 'should mount NFS share' do
          on(host, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

        it 'should remove mount as prep for next test' do
            # use puppet resource instead of simple umount, in order to remove
            # persistent mount configuration
          on(host, %{puppet resource mount #{mount_dir} ensure=absent})
          on(host, "rm -rf #{mount_dir}")
        end
      end
    end
  end
end
