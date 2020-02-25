# This class is used to counterract a bug in ``nfs-utils``
#
# Unless ``lvm2`` is ensured latest, ``nfs-utils`` cannot upgrade
#
# The class will be removed once the bug is fixed upstream
#
# @param ensure
#
class nfs::lvm2 (
  # FIXME  This was originally 'latest', but then changed to 'installed'.  Is
  # it still needed at all?
  String $ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
) {
  package { 'lvm2':
    ensure => $ensure
  }
}
