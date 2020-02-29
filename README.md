[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/nfs.svg)](https://forge.puppetlabs.com/simp/nfs)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/nfs.svg)](https://forge.puppetlabs.com/simp/nfs)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-nfs.svg)](https://travis-ci.org/simp/pupmod-simp-nfs)

#### Table of Contents

* [Description](#description)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
    * [What nfs affects](#what-nfs-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with nfs](#beginning-with-nfs)
* [Usage](#usage)
    * [Basic Usage](#basic-usage)
    * [Usage with krb5](#usage-with-krb5)
    * [Usage with stunnel](#usage-with-stunnel)
    * [Automatic mounting of home directories](#automatic-mounting-of-home-directories)
* [Reference - An under-the-hood peek at what the module is doing and how](#reference)
* [Limitations - OS compatibility, etc.](#limitations)
* [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Description

The is a module for managing the exporting and mounting of NFS devices. It
provides all the infrastructure needed to share folders over the network.

The module is broken into two parts: the server and the client. It supports
security with either krb5 or stunnel, but not both. These security services
conflict at a system level.

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  See the
   ``simp-simp_options`` module for more detail.

## Setup

### What nfs affects

The ``nfs`` module installs NFS packages, configures services for the
NFS server and/or client and manages most NFS configuration files.

### Setup Requirements

The only requirement is to include the nfs module in your modulepath.  If
you are using autofs, please also include SIMP's autofs module in your
modulepath.

### Beginning with nfs

You can use the nfs module to manage NFS settings for a host that is a NFS
client, a NFS server or both.

#### NFS client

Including one or more ``nfs::client::mount`` defines in a host's manifest
will automatically include the ``nfs::client`` class, which, in turn, will
ensure the appropriate packages are installed and appropriate services
are configured and started.

#### NFS server

Including one or more ``nfs::server::export`` defines in a host's manifest
and setting the hiera below will automatically include the ``nfs::server``
class, which, in turn, will ensure the appropriate packages are installed and
appropriate services are configured.

``` yaml
nfs::is_server: true
nfs::is_client: false
```

#### NFS server and client

Including one or more ``nfs::server::export`` or ``nfs::client::mount`` defines
in a host's manifest and setting the hiera below will automatically include
the ``nfs::server`` and ``nfs::client`` classes. This will, in turn, ensure
the appropriate packages are installed and appropriate services are configured
for both roles.

``` yaml
nfs::is_server: true
```

## Usage

### Basic Usage

This section will demonstrate basic usage of the nfs module via two simple
profiles: ``site::nfs_server`` and ``site::nfs_client``.

* ``site::nfs_server`` will export ``/exports/apps`` and ``/exports/home`` on
    the server.
* ``site::nfs_client`` will mount those directories as follows:
    * statically mount ``/export/apps`` as ``/mnt/apps``
    * automount ``/exports/home`` as ``/home`` using an indirect mount, key
      wildcard, and key substitution

``` puppet
class site::nfs_server (
  $kerberos = simplib::lookup('simp_options::kerberos', { 'default_value' => false, 'value_type' => Boolean }),
  $trusted_nets = defined('$simp_options::trusted_nets') ? { true => $simp_options::trusted_nets, default => hiera('simp_options::trusted_nets') }
  ){

  if $kerberos {
    $security = 'krb5p'
  } else {
    $security = 'sys'
  }

  $security = $kerberos ? { true => 'krb5p', false => 'sys' }

  file { '/srv/nfs_share':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0644'
  }

  nfs::server::export { 'nfs4_root':
    client      => $trusted_nets,
    export_path => '/srv/nfs_share',
    sec         => [$security],
    require     => File['/srv/nfs_share']
  }
}
```

And another profile class to be added to a node intended to be a client, to
mount the exported filesystem on a node. Note that all that is needed is the
native Puppet ``mount`` resource:

``` puppet
class site::nfs_client (
    $kerberos = simplib::lookup('simp_options::kerberos', { 'default_value' => false, 'value_type' => Boolean }),
  ){
  include '::nfs'

  $security = $kerberos ? { true => 'krb5p', false =>  'sys' }

  file { '/mnt/nfs':
    ensure => 'directory',
    mode => '755',
    owner => 'root',
    group => 'root'
  }

  mount { "/mnt/nfs":
    ensure  => 'mounted',
    fstype  => 'nfs4',
    device  => '<your_server_ip>:/srv/nfs_share',
    options => "sec=${security}",
    require => File['/mnt/nfs']
  }
}
```

### Usage with krb5

--------------------

> **WARNING**
>
> This functionality requires some manual configuration and when keys
> change may require manual purging of the ``gssproxy`` cache.

--------------------

This module, used with the [SIMP krb5 module](https://github.com/simp/pupmod-simp-krb5),
can automatically use kerberos to secure the exported filesystem. The module
can create and manage the entire kerberos configuration automatically, but
check the krb5 module itself if you want more control.

Modify the examples provided above to include the following hieradata:

To be applied on every node in ``default.yaml``:

``` yaml
simp_options::kerberos : true
nfs::secure_nfs : true

krb5::config::dns_lookup_kdc : false
krb5::kdc::auto_keytabs::global_services:
  - 'nfs'
```

On the node intended to be the server, add ``krb5::kdc`` to the class list:

``` yaml
classes:
  - 'krb5::kdc'
```

Add the following entry to both your ``site::nfs_server`` and
``site::nfs_client`` manifests replacing ``<class_name>`` with the correct
class name (either ``nfs_server`` or ``nfs_client``)

```puppet
Class['krb5::keytab'] -> Class['site::<class_name>']

# If your realm is not your domain name then change this
# to the string that is your realm
# If your kdc server is not the puppet server change admin_server
# entry to the FQDN of your admin server/kdc.

myrealm = inline_template('<%= @domain.upcase %>')

krb5::setting::realm { ${myrealm}:
  admin_server => hiera('puppet::server'),
  default_domain => ${myrealm}
}

```

SIMP does not have kerberos set up to work automatically with LDAP yet.
You must add a pricipal for  each user you want to give access to the krb5 protected
directories.  To do this log onto the KDC and run:

```bash
kadmin.local
# Note the prompt is now kadmin.local!
kadmin.local:  add_principal -pw <password> <username>
...
kadmin.local:  exit
```
When the user logs on after kerberos has been configured they must run:

```bash
kinit
```
It will ask them for their password.  Once the have done this they should be
able to access any shares from that realm.

SIMP does not have kerberos set up to work automatically with LDAP yet. You
must add a pricipal for each user you want to give access to the krb5 protected
directories. To do this log onto the KDC and run:

```bash
kadmin.local
# Note the prompt is now kadmin.local!
kadmin.local:  add_principal -pw <password> <username>
...
kadmin.local:  exit
```
When the user logs on after kerberos has been configured they must run:

```bash
kinit
```

It will ask them for their password. Once the have done this they should be
able to access any shares from that realm.

### Automatic mounting of home directories

Please reference the [SIMP documentation](https://simp.readthedocs.io/en/stable/user_guide/HOWTO/NFS.html#exporting-home-directories) for details on how to implement this feature.

## Reference

Please refer to the [REFERENCE.md](./REFERENCE.md).

## Limitations

This module does not yet manage the following:

* `/etc/nfsmounts.conf`
* `gssproxy` configuration

  * If you are using a custom keytab location, you must fix the `cred_store`
    entries in `/etc/gssproxy/24-nfs-server.conf` and
    `/etc/gssproxy/99-nfs-client.conf`.

* RDMA packages or its service
* `idmapd` configuration for the `umich_ldap` translation method

  * If you need to configure this, consider using `nfs::idmpad::config::content`
    to specify full contents of the `/etc/idmapd.conf` file.

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the [`metadata.json` file](./metadata.json)
for the most up-to-date list of supported operating systems, Puppet versions,
and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
