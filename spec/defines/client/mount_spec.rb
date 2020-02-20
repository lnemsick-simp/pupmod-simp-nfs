require 'spec_helper'

describe 'nfs::client::mount' do
  shared_examples_for 'a base client mount define' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('nfs::client') }
    it { is_expected.to create_nfs__client__mount__connection(title).with_nfs_server(params[:nfs_server]) }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      let(:facts) { os_facts }

      let(:title) { '/home' }
      let(:clean_title) { 'home' }

      context 'with default parameters' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home'
        }}

        include_examples 'a base client mount define'
        it { is_expected.to contain_class('autofs') }

        it {
          is_expected.to contain_autofs__map__entry(title).with_location("#{params[:nfs_server]}:#{params[:remote_path]}")
        }
      end

      context 'without stunnel' do
        context 'with autofs_indirect_map_key' do
          context 'with autofs_add_key_subst=false' do
            let(:params) {{
              :nfs_server              => '1.2.3.4',
              :remote_path             => '/home',
              :autofs_indirect_map_key => 'some_dir'
            }}
            include_examples 'a base client mount define'
          end

          context 'with autofs_add_key_subst=true' do
            let(:params) {{
              :nfs_server              => '1.2.3.4',
              :remote_path             => '/home',
              :autofs_indirect_map_key => '*',
              :autofs_add_key_subst    => true
            }}

            include_examples 'a base client mount define'
          end
        end

        context 'with NFSv4' do
          context 'with custom server port' do
            let(:params) {{
              :nfs_server   => '1.2.3.4',
              :remote_path  => '/home',
              :nfsd_port    => 10000,
            }}

            include_examples 'a base client mount define'
            it {
              is_expected.to create_nfs__client__mount__connection(title).with( {
                :nfs_version  => 4,
                :nfsd_port    => 10000,
              } )
            }
          end
        end

        context 'with NFSv3' do
          let(:pre_condition) {
            <<-EOM
              class { 'nfs': nfsv3 => true }
            EOM
          }
          context 'with default server port' do
            let(:params) {{
              :nfs_server  => '1.2.3.4',
              :remote_path => '/home',
              :nfs_version => 3
            }}

            include_examples 'a base client mount define'

            it {
              is_expected.to create_nfs__client__mount__connection(title).with( {
                :nfs_version  => 3,
                :nfsd_port    => 2049,
              } )
            }
            #FIXME check autofs entry for mount options
          end

          context 'with custom server port' do
            let(:params) {{
              :nfs_server   => '1.2.3.4',
              :remote_path  => '/home',
              :nfs_version  => 3,
              :nfsd_port    => 10002,
            }}

            include_examples 'a base client mount define'
            it {
              is_expected.to create_nfs__client__mount__connection(title).with( {
                :nfs_version  => 3,
                :nfsd_port    => 10002,
              } )
            }
            #FIXME check autofs entry for mount options
          end

        end
      end

      context 'without autofs' do
        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home',
          :autofs  => false
        }}

        include_examples 'a base client mount define'

        it {
          is_expected.to contain_mount(title).with_device("#{params[:nfs_server]}:#{params[:remote_path]}")
        }
        #FIXME check v3 and v4 for mount options
      end

      context 'with stunnel' do
        let(:pre_condition) {
          <<-EOM
            class { 'nfs::client': stunnel => true }
          EOM
        }

        let(:params) {{
          :nfs_server  => '1.2.3.4',
          :remote_path => '/home'
        }}

        include_examples 'a base client mount define'

        it { is_expected.to contain_autofs__map__entry(title).with_location("127.0.0.1:#{params[:remote_path]}") }
        it { is_expected.to contain_exec('reload_autofs') }
        it { is_expected.to contain_stunnel__instance("nfs_#{params[:nfs_server]}:2049_client_nfsd").that_notifies('Exec[reload_autofs]') }

        context 'with nfsv4' do
          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :nfs_version => 4
          }}

          include_examples 'a base client mount define'
          it { is_expected.to contain_nfs__client__stunnel("#{params[:nfs_server]}:2049") }
        end

        context 'without autofs' do
          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :autofs  => false
          }}

          include_examples 'a base client mount define'

          it { is_expected.to contain_mount(title).with_device("127.0.0.1:#{params[:remote_path]}") }
        end
        context 'with tcpwrappers enabled' do
        end
      end

      context 'with firewall enabled' do
        let(:pre_condition) {
          <<-EOM
            class { 'nfs': firewall => true }
          EOM
        }

        context 'NFSv4' do
          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :nfs_version => 4
          }}

          include_examples 'a base client mount define'
          it { is_expected.to contain_class('iptables') }
          it { is_expected.to contain_iptables__listen__tcp_stateful('nfs_callback_1_2_3_4') }
        end

        context 'NFSv3' do
          let(:pre_condition) {
            <<-EOM
              class { 'nfs': firewall=> true, nfsv3 => true }
            EOM
          }

          let(:params) {{
            :nfs_server  => '1.2.3.4',
            :remote_path => '/home',
            :nfs_version => 3
          }}

          include_examples 'a base client mount define'
          it { is_expected.to contain_class('iptables') }
          it { is_expected.to contain_iptables__listen__tcp_stateful('nfs_status_tcp_1_2_3_4') }
          it { is_expected.to contain_iptables__listen__udp('nfs_status_udp_1_2_3_4') }
        end
      end


      context 'when nfs::client::is_server is true but the remote is not the local system' do
        let(:pre_condition) {
          <<-EOM
            class { 'nfs': is_server => true }
          EOM
        }

        let(:params){{
          :nfs_server        => '254.16.1.2',
          :autodetect_remote => false,
          :stunnel           => false,
          :remote_path       => '/home'
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nfs::client') }
        it { is_expected.to contain_autofs__map__entry(title).with_location("#{params[:nfs_server]}:#{params[:remote_path]}") }
      end
    end
  end
end
