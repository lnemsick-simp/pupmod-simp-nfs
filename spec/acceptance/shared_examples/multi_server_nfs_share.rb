# @param server1 Host that will only be a NFS server
# @param server2 Host that will only be a NFS server
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the NFS server manifest
#  * :client_custom - Additional content to be added to the NFS client manifest
#  * :mount1_config - Hash of config to be applied to NFS server and client
#                     for connections to server1
#  * :mount2_config - Hash of config to be applied to NFS server and client
#                     for connections to server1
#
# NOTE:  The following token substitutions are supported:
# * In the :server_custom manifest:
#   * #EXPORTED_DIR#
#
# * In the :client_custom manifest:
#   * #MOUNT_DIR1#
#   * #MOUNT_DIR2#
#   * #SERVER_IP1#
#   * #SERVER_IP2#
#

def build_mount_port_options(config)
  options = ''
  if config[:nfsv3]
    options += "  nfs_version => 3,\n"
  end

  if config[:nfs_sec]
    options += "  sec         => #{config[:nfs_sec]},\n"
  end

  if config[:nfsd_port]
    options += "  nfsd_port   => #{config[:nfsd_port]},\n"
  end

  if config[:stunnel_nfsd_port]
    options += "  stunnel_nfsd_port => #{config[:stunnel_nfsd_port]},\n"
  end

  unless config[:stunnel].nil?
    if config[:stunnel]
      options += "  stunnel    => true,\n"
    else
      options += "  stunnel    => false,\n"
    end
  end

  options
end

shared_examples 'a multi-server NFS share' do |server1, server2, clients, opts|
  let(:exported_dir1) { '/srv/nfs_share1' }
  let(:exported_dir2) { '/srv/nfs_share2' }
  let(:filename) { 'test_file' }
  let(:file_content) { 'This is a test file' }
  let(:server_manifest_base) {
    <<~EOM
      include 'ssh'

      file { '#EXPORTED_DIR#':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      $exported_file = "#EXPORTED_DIR#/#{filename}"
      file { $exported_file:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => '#{file_content}',
      }

      nfs::server::export { 'nfs_root':
        clients     => ['*'],
        export_path => '#EXPORTED_DIR#',
        sec         => ['#NFS_SEC#'],
        insecure    => #EXPORT_INSECURE#
      }

      File['#{exported_dir}'] -> Nfs::Server::Export['nfs_root']

      #{opts[:server_custom]}
    EOM
  }

  let(:mount_port_options1) { build_mount_port_options(opts[:mount1_config]) }
  let(:mount_port_options2) { build_mount_port_options(opts[:mount2_config]) }

  let(:client_manifest_base) {
    <<~EOM
      include 'ssh'

      $mount_dir1 = '#MOUNT_DIR1#'

      nfs::client::mount { $mount_dir1:
        nfs_server  => '#SERVER1_IP#',
        remote_path => '#{exported_dir1}',
        autofs      => false,
      #{mount_port_options1}
      }

      # mount directory must exist if not using autofs
      file { $mount_dir1:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      File[$mount_dir1] -> Nfs::Client::Mount[$mount_dir1]

      $mount_dir2 = '#MOUNT_DIR2#'

      nfs::client::mount { $mount_dir2:
        nfs_server  => '#SERVER2_IP#',
        remote_path => '#{exported_dir2}',
        autofs      => false,
      #{mount_port_options2}
      }

      # mount directory must exist if not using autofs
      file { $mount_dir2:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      File[$mount_dir2] -> Nfs::Client::Mount[$mount_dir2]

      #{opts[:client_custom]}
    EOM
  }

  context "as the first NFS server #{server1}" do
    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end

    it 'should apply server manifest to export' do
      server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
      server_hieradata['nfs::is_client'] = false
      server_hieradata['nfs::is_server'] = true
      server_hieradata['nfs::nfsv3'] = opts[:mount1_config][:nfsv3]
      if opts[:mount1_config][:nfsd_port]
        server_hieradata['nfs::nfsd_port'] = opts[:mount1_config][:nfsd_port]
      end

      if opts[:mount1_config][:stunnel_nfsd_port]
        server_hieradata['nfs::stunnel_nfsd_port'] = opts[:mount1_config][:stunnel_nfsd_port]
      end

      set_hieradata_on(server1, server_hieradata)

      server_manifest = server_manifest_base.dup
      server_manifest.gsub!('#EXPORTED_DIR#', exported_dir1)
      server_manifest.gsub!('#NFS_SEC#', opts[:mount1_config][:nfs_sec])
      server_manifest.gsub!('#EXPORT_INSECURE#', opts[:mount1_config][:export_insecure])
      apply_manifest_on(server1, server_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server1, server_manifest, :catch_changes => true)
    end

    it 'should export shared dir' do
      on(server1, "exportfs -v | grep #{exported_dir1}")
    end
  end

  context "as the second NFS server #{server2}" do
    it 'should apply server manifest to export' do
      server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
      server_hieradata['nfs::is_client'] = false
      server_hieradata['nfs::is_server'] = true
      server_hieradata['nfs::nfsv3'] = opts[:mount2_config][:nfsv3]
      if opts[:mount2_config][:nfsd_port]
        server_hieradata['nfs::nfsd_port'] = opts[:mount2_config][:nfsd_port]
      end

      if opts[:mount2_config][:stunnel_nfsd_port]
        server_hieradata['nfs::stunnel_nfsd_port'] = opts[:mount2_config][:stunnel_nfsd_port]
      end

      server_hieradata.merge!(server_port_overrides_hiera)
      set_hieradata_on(server2, server_hieradata)

      server_manifest = server_manifest_base.dup
      server_manifest.gsub!('#EXPORTED_DIR#', exported_dir2)
      server_manifest.gsub!('#NFS_SEC#', opts[:mount2_config][:nfs_sec])
      server_manifest.gsub!('#EXPORT_INSECURE#', opts[:mount2_config][:export_insecure])
      apply_manifest_on(server2, server_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server2, server_manifest, :catch_changes => true)
    end

    it 'should export shared dir' do
      on(server2, "exportfs -v | grep #{exported_dir2}")
    end
  end

  clients.each do |client|
    context "as a NFS client #{client} using NFS servers #{server1} and #{server2}" do
      mount_dir1 = "/mnt/#{server1}"
      mount_dir2 = "/mnt/#{server2}"

      let(:server1_ip) {
        info = internal_network_info(server1)
        expect(info[:ip]).to_not be_nil
        info[:ip]
      }

      let(:server2_ip) {
        info = internal_network_info(server2)
        expect(info[:ip]).to_not be_nil
        info[:ip]
      }

      let(:client_manifest) {
        client_manifest = client_manifest_base.dup
        client_manifest.gsub!('#MOUNT_DIR1#', mount_dir1)
        client_manifest.gsub!('#MOUNT_DIR2#', mount_dir2)
        client_manifest.gsub!('#SERVER1_IP#', server_ip1)
        client_manifest.gsub!('#SERVER2_IP#', server_ip2)
        client_manifest
      }

      it "should apply client manifest to mount a dir from each server" do
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

      {
        server1 => mount_dir1,
        server2 => mount_dir2
      }.each do |server,mount_dir|

        it "should mount NFS share from #{server}" do
          on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
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
