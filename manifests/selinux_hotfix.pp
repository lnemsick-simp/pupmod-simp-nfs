# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# This class provides a hotfix for a broken SELinux policy in EL7,
# selinux-policy < 3.13.1-229.el7_6.9.
#
# The OS confinement of this class should be done elsewhere
#
class nfs::selinux_hotfix {
  assert_private()

  if $facts['selinux_current_mode'] and $facts['selinux_current_mode'] != 'disabled' {
    vox_selinux::module { 'gss_hotfix':
      ensure     => 'present',
      content_te => file("${module_name}/selinux/gss_hotfix.te"),
      builder    => 'simple'
    }
  }
}
