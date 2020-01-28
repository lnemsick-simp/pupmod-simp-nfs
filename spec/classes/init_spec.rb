require 'spec_helper'

describe 'nfs' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      shared_examples_for 'a NFS base installer' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs') }
        it { is_expected.to create_package('nfs-utils').with_ensure('installed') }
        it { is_expected.to create_package('nfs4-acl-tools').with_ensure('installed') }
#FIXME el8 quota-rpc
      end

      context 'with default parameters' do

        it_behaves_like 'a NFS base installer'
#FIXME      it { is_expected.to create_concat__fragment('nfs_init').with_content(%r(MOUNTD_PORT=20048)) }
        it { is_expected.to create_class('nfs::client') }
        it { is_expected.to_not create_class('nfs::server') }

      end

      context 'nfs client only' do
        context 'NFSv3 disabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end

        context 'NFSv3 enabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :nfsv3           => true,
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end
      end

      context 'nfs server only' do
        context 'NFSv3 disabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end

        context 'NFSv3 enabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_client => false,
              :is_server => true,
              :nfsv3           => true,
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end
      end

      context 'nfs server and client' do
        context 'NFSv3 disabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end

        context 'NFSv3 enabled' do
          context 'firewall and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'stunnel, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :nfsv3       => true,
              :firewall    => true,
              :tcpwrappers => true,
              :stunnel     => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end

          context 'secure NFS, kerberos, firewall, and tcpwrappers enabled' do
            let(:params){{
              :is_server => true,
              :nfsv3           => true,
              :firewall         => true,
              :tcpwrappers      => true,
              :kerberos         => true,
              :keytab_on_puppet => true,
            }}

            it { is_expected.to compile.with_all_deps }
          end
        end
      end

=begin

      context 'as a client and server with default params' do
        let(:params){{
          :is_server => true
        }}
        it_behaves_like 'a NFS base installer'
        it { is_expected.to create_class('nfs::client') }
        it { is_expected.to create_class('nfs::server') }
        it { is_expected.to_not create_class('tcpwrappers') }
        it { is_expected.to_not create_class('krb5') }
#FIXME        it { is_expected.to create_concat__fragment('nfs_init').with_content(/SECURE_NFS=no/) }
        it { is_expected.to create_concat('/etc/sysconfig/nfs') }
        it { is_expected.to create_exec('nfs_re-export').with({
            :command     => '/usr/sbin/exportfs -ra',
            :refreshonly => true
          })
        }

        it { is_expected.to create_service('nfs-server.service').with({
            :ensure  => 'running'
          })
        }

        it { is_expected.to create_sysctl('sunrpc.tcp_slot_table_entries') }
        it { is_expected.to create_sysctl('sunrpc.udp_slot_table_entries') }
      end

      context 'as a client and server with NFSv3 enabled' do
        let(:params){{
          :is_server => true,
          :nfsv3     => true
        }}

        it_behaves_like 'a NFS base installer'
        it { is_expected.to create_class('nfs::client') }
        it { is_expected.to create_class('nfs::server') }
      end

      context 'as a server only' do
        let(:params){{
          :is_client => false,
          :is_server => true
        }}

        it_behaves_like 'a NFS base installer'
        it { is_expected.to_not create_class('nfs::client') }
        it { is_expected.to create_class('nfs::server') }
      end

      context 'as a server only with NFSv3 enabled' do
        let(:params){{
          :is_client => false,
          :is_server => true,
          :nfsv3     => true
        }}

        it_behaves_like 'a NFS base installer'
        it { is_expected.to_not create_class('nfs::client') }
        it { is_expected.to create_class('nfs::server') }
      end

      context "as a server with custom args" do
#        let(:hieradata) { 'rpcgssdargs' }
        let(:params) {{
          :is_server   => true,
          :tcpwrappers => true,
          :stunnel     => true,
          :kerberos    => true,
          :firewall    => true
        }}
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs') }
        it { is_expected.to create_class('nfs::server') }
        it { is_expected.to create_concat__fragment('nfs_init_server').with_content(%r(\nRPCSVCGSSDARGS="-n -vvvvv -rrrrr -iiiiii")) }
        it { is_expected.to create_class('tcpwrappers') }
#        it { is_expected.to create_tcpwrappers__allow('nfs') }
#        it { is_expected.to create_tcpwrappers__allow('mountd') }
#        it { is_expected.to create_tcpwrappers__allow('statd') }
#        it { is_expected.to create_tcpwrappers__allow('rquotad') }
#        it { is_expected.to create_tcpwrappers__allow('lockd') }
#        it { is_expected.to create_tcpwrappers__allow('rpcbind') }
        it { is_expected.to create_class('krb5') }
#        it { is_expected.to create_concat__fragment('nfs_init').with_content(/SECURE_NFS=no/) }
      end

      context 'with secure_nfs => true' do
# why using hieradata?  can all be parameters
        let(:hieradata) { 'server_secure' }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_concat__fragment('nfs_init').with_content(/SECURE_NFS=yes/) }

        if facts[:operatingsystemmajrelease] >= '7'
          it { is_expected.to create_service('rpc-gssd.service').with(:ensure => 'running') }
          if facts[:os][:release][:full] >= '7.1.0'
            it { is_expected.to create_service('gssproxy.service').with(:ensure => 'running') }
          else
            it { is_expected.to create_service('rpc-svcgssd.service').with(:ensure => 'running') }
          end
        else
          it { is_expected.to create_service('rpcgssd').with(:ensure => 'running') }
          it { is_expected.to create_service('rpcsvcgssd').with(:ensure => 'running') }
        end
      end
=end
    end
  end
end
