require 'spec_helper'

# Testing private nfs::server::firewall class via nfs class
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }

  context 'when stunnel enabled' do
    context 'when nfsv3 enabled' do
      let(:params) { {
        # nfs class params
        :is_server => true,
        :nfsv3     => true,
        :firewall  => true,
        :stunnel   => true
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::server::firewall') }
      it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
      it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
    end

    context 'when nfsv3 disabled' do
      let(:params) { {
        # nfs class params
        :is_server => true,
        :nfsv3     => false,
        :firewall  => true,
        :stunnel   => true
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::server::firewall') }
      it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
      it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
    end
  end

  context 'when stunnel disabled' do
    context 'when nfsv3 enabled' do
      let(:params) { {
        # nfs class params
        :is_server => true,
        :nfsv3     => true,
        :firewall  => true,
        :stunnel   => false
      }}
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::server::firewall::nfsv3and4') }
      it { is_expected.to_not create_class('nfs::server::firewall::nfsv4') }
    end

    context 'when nfsv3 disabled' do
      let(:params) { {
        # nfs class params
        :is_server => true,
        :nfsv3     => false,
        :firewall  => true,
        :stunnel   => false
      }}
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to_not create_class('nfs::server::firewall::nfsv3and4') }
      it { is_expected.to create_class('nfs::server::firewall::nfsv4') }
    end
  end
end
