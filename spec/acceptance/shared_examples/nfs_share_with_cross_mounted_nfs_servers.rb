# Verify a complex configuration with 2 servers and an array of clients:
# * NFS server 1 mounts a directory from NFS server 2
# * NFS server 2 mounts a directory from NFS server 1
# * Each NFS client mounts directories from both NFS servers
#
# This test is most useful for verifying a client supports simultaneous
# stunneled and non-stunneled connections to different servers.
#
# Characteristics of the server capabilities, server exports and clients mounts
# (e.g., stunnel, NFSv4 or NFSv3, insecure export) are controlled by opts.
#
# @param server1 Host that will only be a NFS server
# @param server2 Host that will only be a NFS server
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera - Base hieradata to be added to nfs-specific hieradata for all
#                  hosts
#  * :server1_config - Hash of config to be applied to the first NFS server
#  * :server2_config - Hash of config to be applied to the second NFS server
#  * :client_config - Hash of config to be applied to each NFS client
#

def build_server_plus_client_hieradata(base_hiera, config)
  hiera = Marshal.load(Marshal.dump(base_hiera))
  hiera['nfs::is_client'] = true
  hiera['nfs::is_server'] = true
  hiera['nfs::nfsv3'] = config[:nfsv3] unless config[:nfsv3].nil?
  hiera['nfs::nfsd_port'] = config[:nfsd_port] unless config[:nfsd_port].nil?
  hiera['nfs::stunnel_nfsd_port'] = config[:stunnel_nfsd_port] unless config[:stunnel_nfsd_port].nil?
  hiera.compact
end

def build_server_plus_client_manifest(manifest_base, opts)
  server_manifest = manifest_base.dup
  server_manifest.gsub!('#EXPORTED_DIR#', opts[:exported_dir])
  server_manifest.gsub!('#EXPORT_SEC#', opts[:export_sec])
  server_manifest.gsub!('#EXPORT_INSECURE#', opts[:export_insecure].to_s)
  server_manifest.gsub!('#MOUNT_DIR#', opts[:mount_dir])
  server_manifest.gsub!('#MOUNT_SERVER_IP#', opts[:mount_server_ip])
  server_manifest.gsub!('#MOUNT_NFS_VERSION#', opts[:mount_nfs_version].to_s)
  server_manifest.gsub!('#MOUNT_REMOTE_DIR#', opts[:mount_remote_dir])
  server_manifest.gsub!('#MOUNT_OPTIONS#', opts[:mount_options])
  server_manifest
end

shared_examples 'a NFS share with cross-mounted servers' do |server1, server2, clients, opts|
  let(:server1_opts) { {
    :exported_dir      => opts[:server1_config][:exported_dir],
    :export_sec        => opts[:server1_config][:export_sec],
    :export_insecure   => opts[:server1_config][:export_insecure],
    :mount_dir         => "/mnt/#{opts[:server2_config][:server_name]}-#{File.basename(opts[:server2_config][:exported_dir])}",
    :mount_server_ip   => opts[:server2_config][:server_ip],
    :mount_remote_dir  => opts[:server2_config][:exported_dir],
    :mount_nfs_version => opts[:server1_config][:mount_nfs_version],
    :mount_options     => build_mount_options( {
        :nfs_sec       => opts[:server1_config][:mount_sec],
        :nfsd_port     => opts[:server2_config][:nfsd_port],
        :mount_stunnel => opts[:server1_config][:mount_stunnel],
      } )
  } }

  let(:server2_opts) { {
    :exported_dir      => opts[:server2_config][:exported_dir],
    :export_sec        => opts[:server2_config][:export_sec],
    :export_insecure   => opts[:server2_config][:export_insecure],
    :mount_dir         => "/mnt/#{opts[:server1_config][:server_name]}-#{File.basename(opts[:server1_config][:exported_dir])}",
    :mount_server_ip   => opts[:server1_config][:server_ip],
    :mount_remote_dir  => opts[:server1_config][:exported_dir],
    :mount_nfs_version => opts[:server2_config][:mount_nfs_version],
    :mount_options     => build_mount_options( {
        :nfs_sec       => opts[:server2_config][:mount_sec],
        :nfsd_port     => opts[:server2_config][:nfsd_port],
        :mount_stunnel => opts[:server2_config][:mount_stunnel],
      } )
  } }

  let(:filename) { 'test_file' }
  let(:file_content) { 'This is a test file' }

  let(:server_manifest_export_base) {
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
        sec         => ['#EXPORT_SEC#'],
        insecure    => #EXPORT_INSECURE#
      }

      File['#EXPORTED_DIR#'] -> Nfs::Server::Export['nfs_root']
    EOM
  }

  let(:mount_base) {
    <<~EOM
      nfs::client::mount { '#MOUNT_DIR#':
        nfs_server  => '#MOUNT_SERVER_IP#',
        nfs_version => #MOUNT_NFS_VERSION#,
        remote_path => '#MOUNT_REMOTE_DIR#',
        autofs      => false,
        #MOUNT_OPTIONS#
      }

      # mount directory must exist if not using autofs
      file { '#MOUNT_DIR#':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      File['#MOUNT_DIR#'] -> Nfs::Client::Mount['#MOUNT_DIR#']
    EOM
  }

  let(:server_manifest_export_and_mount_base) {
    <<~EOM
      #{server_manifest_export_base}

      #{mount_base}
    EOM
  }

  # Just do the exports first, so we can then apply a manifest that exports
  # and mounts and have it succeed next
  context 'server initial exports' do
    context "as the first NFS server #{server1}" do
      let(:server_manifest) {
        # will actually only be server manifest
        build_server_plus_client_manifest(server_manifest_export_base, server1_opts)
      }

      it 'should apply server manifest to export' do
        server_hieradata = build_server_plus_client_hieradata(opts[:base_hiera],opts[:server1_config])
        set_hieradata_on(server1, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server1, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server1, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server1, 'exportfs -v')
        on(server1, "exportfs -v | grep #{server1_opts[:exported_dir]}")
      end
    end

    context "as the second NFS server #{server2}" do
      let(:server_manifest) {
        # will actually only be server manifest
        build_server_plus_client_manifest(server_manifest_export_base, server2_opts)
      }

      it 'should apply server manifest to export' do
        server_hieradata = build_server_plus_client_hieradata(opts[:base_hiera],opts[:server2_config])
        set_hieradata_on(server2, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server2, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server2, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server2, 'exportfs -v')
        on(server2, "exportfs -v | grep #{server2_opts[:exported_dir]}")
      end
    end
  end

  context 'vagrant connectivity' do
    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end
  end

  context 'server exports and mounts' do
    context "as the first NFS server #{server1}" do
      let(:server_manifest) {
        build_server_plus_client_manifest(server_manifest_export_and_mount_base, server1_opts)
      }

      it 'should apply server manifest to export' do
        server_hieradata = build_server_plus_client_hieradata(opts[:base_hiera],opts[:server1_config])
        set_hieradata_on(server1, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server1, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server1, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server1, 'exportfs -v')
        on(server1, "exportfs -v | grep #{server1_opts[:exported_dir]}")
      end

      it "should mount NFS share from #{server2}" do
        on(server1, "mount | grep #{server1_opts[:mount_dir]}")
        on(server1, %(grep -q '#{file_content}' #{server1_opts[:mount_dir]}/#{filename}))
      end
    end

    context "as the second NFS server #{server2}" do
      let(:server_manifest) {
        # will actually only be server manifest
        build_server_plus_client_manifest(server_manifest_export_and_mount_base, server2_opts)
      }

      it 'should apply server manifest to export' do
        server_hieradata = build_server_plus_client_hieradata(opts[:base_hiera],opts[:server2_config])
        set_hieradata_on(server2, server_hieradata)
        print_test_config(server_hieradata, server_manifest)
        apply_manifest_on(server2, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(server2, server_manifest, :catch_changes => true)
      end

      it 'should export shared dir' do
        on(server2, 'exportfs -v')
        on(server2, "exportfs -v | grep #{server2_opts[:exported_dir]}")
      end

      it "should mount NFS share from #{server1}" do
        on(server2, "mount | grep #{server2_opts[:mount_dir]}")
        on(server2, %(grep -q '#{file_content}' #{server2_opts[:mount_dir]}/#{filename}))
      end
    end
  end

=begin
  let(:mount_port_options1) { build_mount_port_options(opts[:config1]) }
  let(:mount_port_options2) { build_mount_port_options(opts[:config2]) }

  clients.each do |client|
    context "as a NFS client #{client} using NFS servers #{server1} and #{server2}" do
      mount_dir1 = "/mnt/#{server1}"
      mount_dir2 = "/mnt/#{server2}"


      let(:client_manifest) {
        client_manifest = client_manifest_base.dup
        client_manifest.gsub!('#MOUNT_DIR1#', mount_dir1)
        client_manifest.gsub!('#MOUNT_DIR2#', mount_dir2)
        client_manifest.gsub!('#SERVER1_IP#', server1_ip)
        client_manifest.gsub!('#SERVER2_IP#', server2_ip)
        client_manifest
      }

      it 'should ensure vagrant connectivity' do
        on(hosts, 'date')
      end

      it "should apply client manifest to mount a dir from each server" do
        client_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
        client_hieradata['nfs::is_client'] = true
        client_hieradata['nfs::is_server'] = false
        # if either mount will be NFSv3, enable NFSv3 on the client
        nfsv3 = opts[:config1][:nfsv3] || opts[:config2][:nfsv3]
        client_hieradata['nfs::nfsv3'] = nfsv3
        set_hieradata_on(client, client_hieradata)
        print_test_config(client_hieradata, client_manifest)
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
          on(client, "mount | grep #{mount_dir}")
          on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
        end

      end
    end
  end

  context 'cleanup' do
    clients.each do |client|
        it 'should remove mount as prep for next test' do
          # use puppet resource instead of simple umount, in order to remove
          # persistent mount configuration
          on(client, %{puppet resource mount #{mount_dir} ensure=absent})
          on(client, "rm -rf #{mount_dir}")
        end
    end
  end
=end
end
