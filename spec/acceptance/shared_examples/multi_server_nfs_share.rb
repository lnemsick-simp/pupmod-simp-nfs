# @param servers Array of Hosts that will only be NFS servers
# @param clients Array of Hosts that will only be NFS clients
#
# @param opts Hash of test options with the following keys:
#  * :base_hiera    - Base hieradata to be added to nfs-specific hieradata
#  * :server_custom - Additional content to be added to the NFS server manifest
#  * :client_custom - Additional content to be added to the NFS client manifest
#  * :port_overrides - Hash of port overrides to be used in configuring the
#                     second server. When running stunnel tests, MUST be
#                     different from the defaults used in the first server.
#  * :nfsv3         - Whether this is testing NFSv3.  When true, NFSv3 will be
#                     enabled (server + client) and used in the client mount
#  * :nfs_sec       - NFS security option to use in both the server export and
#                     the client mount
#  * :export_insecure - insecure setting for NFS export
#  * :verify_reboot - Whether to verify idempotency and mount functionality
#                     after individually rebooting the client and server
#                     in each test pair
#
# NOTE:  The following token substitutions are supported:
# * In the :server_custom manifest:
#   * #EXPORTED_DIR#
#
# * In the :client_custom manifest:
#   * #MOUNT_DIR1#
#   * #MOUNT_DIR2#
#   * #PORT_OPTIONS#
#   * #SERVER_IP1#
#   * #SERVER_IP2#
#
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
        sec         => ['#{opts[:nfs_sec]}'],
        insecure    => #{opts[:export_insecure]}
      }

      File['#{exported_dir}'] -> Nfs::Server::Export['nfs_root']

      #{opts[:server_custom]}
    EOM
  }

  let(:nfs_version) { opts[:nfsv3] ? 3 : 4 }
  let(:server_port_overrides_hiera) {
    opts[:port_overrides].map { |name,value| ["nfs::#{name}",value] }.to_h
  }

  let(:mount_port_overrides_nfsv3) {
    <<~EOM
      lockd_port           => #{opts[:port_overrides][:lockd_port_server]},
      mountd_port          => #{opts[:port_overrides][:mountd_port]},
      nfsd_port            => #{opts[:port_overrides][:nfsd_port]},
      rquotad_port         => #{opts[:port_overrides][:rquotad_port]},
      statd_port           => #{opts[:port_overrides][:statd_port_server]},
      stunnel_lockd_port   => #{opts[:port_overrides][:stunnel_lockd_port]},
      stunnel_mountd_port  => #{opts[:port_overrides][:stunnel_lockd_port]},
      stunnel_nfsd_port    => #{opts[:port_overrides][:stunnel_nfsd_port]},
      stunnel_rquotad_port => #{opts[:port_overrides][:stunnel_rquotad_port]},
      stunnel_statd_port   => #{opts[:port_overrides][:stunnel_statd_port]}
   EOM
  }

  let(:mount_port_overrides_nfsv4) {
    <<~EOM
      nfsd_port            => #{opts[:port_overrides][:nfsd_port]},
      rquotad_port         => #{opts[:port_overrides][:rquotad_port]},
      stunnel_nfsd_port    => #{opts[:port_overrides][:stunnel_nfsd_port]},
      stunnel_rquotad_port => #{opts[:port_overrides][:stunnel_rquotad_port]},
   EOM
  }

  let(:client_manifest_base) {
    <<~EOM
      include 'ssh'

      $mount_dir1 = '#MOUNT_DIR1#'

      nfs::client::mount { $mount_dir1:
        nfs_server  => '#SERVER1_IP#',
        nfs_version => #{nfs_version},
        remote_path => '#{exported_dir1}',
        sec         => '#{opts[:nfs_sec]}',
        autofs      => false
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
        nfs_server           => '#SERVER2_IP#',
        nfs_version          => #{nfs_version},
        remote_path          => '#{exported_dir2}',
        sec                  => '#{opts[:nfs_sec]}',
        autofs               => false,
      #PORT_OPTIONS#
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

  context "as a NFS server #{server1} using default ports" do
    it 'should ensure vagrant connectivity' do
      on(hosts, 'date')
    end

    it 'should apply server manifest to export' do
      server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
      server_hieradata['nfs::is_client'] = false
      server_hieradata['nfs::is_server'] = true
      server_hieradata['nfs::nfsv3'] = opts[:nfsv3]
      set_hieradata_on(server1, server_hieradata)

      server_manifest = server_manifest_base.dup
      server_manifest.gsub!('#EXPORTED_DIR#', exported_dir1)
      apply_manifest_on(server1, server_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server1, server_manifest, :catch_changes => true)
    end

    it 'should export shared dir' do
      on(server1, "exportfs -v | grep #{exported_dir1}")
    end
  end

  context "as a NFS server #{server2} using custom ports" do
    it 'should apply server manifest to export' do
      server_hieradata = Marshal.load(Marshal.dump(opts[:base_hiera]))
      server_hieradata['nfs::is_client'] = false
      server_hieradata['nfs::is_server'] = true
      server_hieradata['nfs::nfsv3'] = opts[:nfsv3]
      server_hieradata.merge!(server_port_overrides_hiera)
      set_hieradata_on(server2, server_hieradata)

      server_manifest = server_manifest_base.dup
      server_manifest.gsub!('#EXPORTED_DIR#', exported_dir2)
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
        client_manifest.gsub!('#SERVER_IP1#', server_ip1)
        client_manifest.gsub!('#SERVER_IP2#', server_ip2)
        if opts[:nfsv3]
          client_manifest.gsub!('#PORT_OPTIONS#', mount_port_overrides_nfsv3)
        else
          client_manifest.gsub!('#PORT_OPTIONS#', mount_port_overrides_nfsv4)
        end
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
          it "should communicate lock status with NFS server #{server}" do
            require 'timeout'

            # When testing with tcpwrappers (el7), times out on the first
            # attempt but then succeed on the second attempt
            # TODO Figure out why this happens
            tries = 2
            begin
              lock_seconds = 1
              timeout_seconds = lock_seconds + 30
              Timeout::timeout(timeout_seconds) do
                on(client, "flock  #{mount_dir}/#{filename} -c 'sleep #{lock_seconds}'")
              end
            rescue Timeout::Error
              tries -= 1
              if tries == 0
                fail('Problem with NFSv3 connectivity during file lock')
              else
                retry
              end
            end
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

        {
          server1 => mount_dir1,
          server2 => mount_dir2
        }.each do |server,mount_dir|
          it "mount to #{server} should be re-established after client reboot" do
            on(client, %(grep -q '#{file_content}' #{mount_dir}/#{filename}))
          end

          it "server manifest should be idempotent on #{server} after reboot" do
            server.reboot
            apply_manifest_on(server, server_manifest, :catch_changes => true)
          end

          it "mount should be re-established after server #{server} reboot" do
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
