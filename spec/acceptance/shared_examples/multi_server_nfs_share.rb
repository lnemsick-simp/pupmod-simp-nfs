# Verify a NFS client can mount directories from two NFS servers simultaneously.
#
#   client mount ----> server1 exported dir
#               \
#                ----> server2 exported dir
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
#  * :config1    - Hash of config to be applied to NFS server and client to
#                  affect type of mount to server1
#  * :config2    - Hash of config to be applied to NFS server and client to
#                  to affect type of mount to server2
#
# Hash keys in opts[:config1] and [:config2]
# * :export_insecure - nfs::server::export::insecure, must be true for
#   stunneled mounts (NFSv4)
# * :nfsv3 - When true, nfs::nfsv3 is set to true on both server and client and
#   nfs::client::mount::nfs_version is set to 3.
# * :nfs_sec - Value of nfs::server::export::sec (within an Array) and
#   nfs::client::mount::sec.
# * :nfsd_port - When set, value of nfs::nfsd_port and
#   nfs::client::mount::nfsd_port. Otherwise, the defaults will apply.
# * :stunnel_nfsd_port - When set, value of nfs::stunnel_nfsd_port and
#   nfs::client::mount::stunnel_nfsd_port. Otherwise, the defaults will apply.
# * :mount_stunnel - When set, used for nfs::client::mount::stunnel. Otherwise,
#   the default will apply.
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

  unless config[:mount_stunnel].nil?
    if config[:mount_stunnel]
      options += "  stunnel    => true,\n"
    else
      options += "  stunnel    => false,\n"
    end
  end

  options
end

def build_server_hieradata(base_hiera, config)
  hiera = Marshal.load(Marshal.dump(base_hiera))
  hiera['nfs::is_client'] = false
  hiera['nfs::is_server'] = true
  hiera['nfs::nfsv3'] = config[:nfsv3]
  hiera['nfs::nfsd_port'] = config[:nfsd_port]
  hiera['nfs::stunnel_nfsd_port'] = config[:stunnel_nfsd_port]
  hiera.compact
end

def build_server_manifest(manifest_base, config, exported_dir)
  server_manifest = manifest_base.dup
  server_manifest.gsub!('#EXPORTED_DIR#', exported_dir)
  server_manifest.gsub!('#NFS_SEC#', config[:nfs_sec])
  server_manifest.gsub!('#EXPORT_INSECURE#', config[:export_insecure].to_s)
  server_manifest
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

      File['#EXPORTED_DIR#'] -> Nfs::Server::Export['nfs_root']
    EOM
  }

  let(:mount_port_options1) { build_mount_port_options(opts[:config1]) }
  let(:mount_port_options2) { build_mount_port_options(opts[:config2]) }

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
    EOM
  }

  context "as the first NFS server #{server1}" do
    let(:server_manifest) {
      build_server_manifest(server_manifest_base, opts[:config1], exported_dir1)
    }

    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end

    it 'should apply server manifest to export' do
      server_hieradata = build_server_hieradata(opts[:base_hiera],opts[:config1])
      set_hieradata_on(server1, server_hieradata)
      print_test_config(server_hieradata, server_manifest)
      apply_manifest_on(server1, server_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server1, server_manifest, :catch_changes => true)
    end

    it 'should export shared dir' do
      on(server1, 'exportfs -v')
      on(server1, "exportfs -v | grep #{exported_dir1}")
    end
  end

  context "as the second NFS server #{server2}" do
    let(:server_manifest) {
      build_server_manifest(server_manifest_base, opts[:config2], exported_dir2)
    }

    it 'should apply server manifest to export' do
      server_hieradata = build_server_hieradata(opts[:base_hiera],opts[:config2])
      set_hieradata_on(server2, server_hieradata)
      print_test_config(server_hieradata, server_manifest)
      apply_manifest_on(server2, server_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server2, server_manifest, :catch_changes => true)
    end

    it 'should export shared dir' do
      on(server2, 'exportfs -v')
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
        client_manifest.gsub!('#SERVER1_IP#', server1_ip)
        client_manifest.gsub!('#SERVER2_IP#', server2_ip)
        client_manifest
      }

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
