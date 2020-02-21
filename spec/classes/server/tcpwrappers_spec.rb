require 'spec_helper'

# Testing private nfs::server::tcpwrappers class via nfs class
describe 'nfs' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      context 'when tcpwrappers and nfsv3 enabled' do
        let(:params) {{
          # nfs class params
          :is_server   => true,
          :nfsv3       => true,
          :tcpwrappers => true
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('nfs::server::tcpwrappers') }

        if os_facts[:os][:release][:major].to_i > 7
          it { is_expected.to_not create_class('tcpwrappers') }
          it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
          it { is_expected.to_not create_tcpwrappers__allow('statd') }
          it { is_expected.to_not create_tcpwrappers__allow('mountd') }
          it { is_expected.to_not create_tcpwrappers__allow('rquotad') }
        else
          it { is_expected.to create_class('tcpwrappers') }
          it { is_expected.to create_tcpwrappers__allow('rpcbind') }
          it { is_expected.to create_tcpwrappers__allow('statd') }
          it { is_expected.to create_tcpwrappers__allow('mountd') }
          it { is_expected.to create_tcpwrappers__allow('rquotad') }
        end
      end

      context 'when tcpwrappers enabled and nfsv3 disabled' do
        let(:params) {{
          # nfs class params
          :is_server   => true,
          :nfsv3       => false,
          :tcpwrappers => true
        }}

        if os_facts[:os][:release][:major].to_i > 7
          it { is_expected.to_not create_class('tcpwrappers') }
          it { is_expected.to_not create_tcpwrappers__allow('rpcbind') }
          it { is_expected.to_not create_tcpwrappers__allow('statd') }
          it { is_expected.to_not create_tcpwrappers__allow('mountd') }
          it { is_expected.to_not create_tcpwrappers__allow('rquotad') }
        else
          it { is_expected.to create_class('tcpwrappers') }
          it { is_expected.to create_tcpwrappers__allow('rpcbind') }
          it { is_expected.to_not create_tcpwrappers__allow('statd') }
          it { is_expected.to_not create_tcpwrappers__allow('mountd') }
          it { is_expected.to create_tcpwrappers__allow('rquotad') }
        end
      end
    end
  end
end
