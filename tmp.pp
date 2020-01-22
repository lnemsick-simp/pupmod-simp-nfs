Stdlib::AbsolutePath   general_pipefs_directory      = undef, # /var/lib/nfs/rpc_pipefs

Optional[DebugOptions] exportfs_debug                = undef, # FIXME 0?

Boolean                gssd_use_memcache             = undef, # false
Boolean                gssd_use_machine_creds        = undef, # true
Boolean                gssd_use_gss_proxy            = true,  # true el7 written to /etc/sysconfig/nfs as USE_GSS_PROXY instead
Boolean                gssd_avoid_dns                = undef, # true
Boolean                gssd_limit_to_legacy_enctypes = false, # false
Integer[0]             gssd_context_timeout          = undef, # 0
Integer[0]             gssd_rpc_timeout              = undef, # 5
Stdlib::AbsolutePath   gssd_keytab_file              = undef, # '/etc/krb5.keytab'
Stdlib::AbsolutePath   gssd_cred_cache_directory     = undef, # ' /tmp:/run/user/%U'
String                 gssd_preferred_realm          = undef, # default in Kerberos config file
Integer[0]             gssd_rpc_verbosity            = undef, # 0
Simplib::Port          lockd_port                    =        # 0
Simplib::Port          lockd_udp_port                =        # 0

Optional[DebugOptions] mountd_debug                  = undef, # 0
Boolean                mountd_manage_gids            = undef, # false
Integer[0]             mountd_descriptors            = undef, # 0
Simplib::Port          mountd_port                   =      , # 0
Integer[1]             mountd_threads                = undef, # 1
Boolean                mountd_reverse_lookup         = undef, # false
Stdlib::AbsolutePath   mountd_state_directory_path   = undef, # /var/lib/nfs
Stdlib::AbsolutePath   mountd_ha_callout             = undef, #

Optional[DebugOptions] nfsdcltrack_debug             = undef, # 0
Stdlib::AbsolutePath   nfsdcltrack_storagedir        = undef, # /var/lib/nfs/nfsdcltrack

Optional[DebugOptions] nfsd_debug                    = undef, # 0
Integer[1]             nfsd_threads                  =      , # 8
Array[Simplib::Host]   nfsd_host                     =      
Simplib::Port          nfsd_port                     =      , # 0
Integer[1]             nfsd_grace_time               = undef, # 90 <- should this be set?
Integer[1]             nfsd_lease_time               = undef, # 90
Boolean                nfsd_udp                      =      , # true
Boolean                nfsd_tcp                      =      , # true
Boolean                nfsd_vers2                    =      , # false
Boolean                nfsd_vers3                    =      , # true
Boolean                nfsd_vers4                    =      , # true
Boolean                nfsd_vers4.0                  =      , # true
Boolean                nfsd_vers4.1                  =      , # true
Boolean                nfsd_vers4.2                  =      , # true
Variant[String,Simplib::Port] nfsd_rdma              = undef, # n
#Nfs::Rdma

Optional[DebugOptions] statd_debug                   = undef,
Simplib::Port          statd_port                    =      , # 0
Simplib::Port          statd_outgoing_port           =      , # 0
Simplib::Host          statd_name                    = undef, #
Stdlib::AbsolutePath   statd_state_directory_path    = undef, # /var/lib/nfs/statd
Stdlib::AbsolutePath   statd_ha_callout              = undef, #
Boolean                statd_no_notify               = undef, # false

Optional[DebugOptions] sm_notify_debug               = undef,
Boolean                sm_notify_force               = undef, # false
Integer[0]             sm_notify_retry_time          = undef, # 15m (erroneously 900s in example)
Simplib::Port          sm_notify_outgoing_port       = undef, # 0
Simplib::Host          sm_notify_outgoing_addr       = undef, #
Boolean                sm_notify_lift_grace          = undef, # true
Boolean                sm_notify_update_state        = undef,   # true , false corresponds to sm-notify -n option <-- only applies el8

Optional[Hash]         custom_nfs_conf_options       = undef #key = section, value is a hash of settings
 
