require 'spec_helper'

# Testing private nfs::client class via nfs class
describe 'nfs' do
  # What we are testing is not fact-dependent, but need facts for
  # nfs class.  So, grab first set of supported OS facts.
  let(:facts) { on_supported_os.to_a[0][1] }

  context 'with default nfs and nfs::client parameters' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('nfs::client::config') }
    it { is_expected.to create_class('nfs::base::config') }
    it { is_expected.to create_class('nfs::base::service') }
    it { is_expected.to create_class('nfs::client::config') }
    it { is_expected.to create_class('nfs::client::service') }
    it { is_expected.to_not create_class('krb5') }
    it { is_expected.to_not create_class('krb5::keytab') }
  end


  context 'with nfs::kerberos = true' do
    context 'with nfs::keytab_on_puppet = false' do
      let(:params) {{
        # nfs class params
        :kerberos         => true,
        :keytab_on_puppet => false
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::client') }
      it { is_expected.to create_class('krb5') }
      it { is_expected.to_not create_class('krb5::keytab') }
    end

    context 'with nfs::keytab_on_puppet = true' do
      let(:params) {{
        # nfs class params
        :kerberos         => true,
        :keytab_on_puppet => true
      }}

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('nfs::client') }
      it { is_expected.to create_class('krb5') }
      it { is_expected.to create_class('krb5::keytab') }
    end
  end
end
