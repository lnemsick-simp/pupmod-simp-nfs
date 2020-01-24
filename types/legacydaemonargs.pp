# Legacy NFS daemon *ARGS environment variables set in /etc/sysconfig/nfs
type Nfs::LegacyDaemonArgs = Struct[{
  Optional['RPCIDMAPDARGS'] => String,
  Optional['RPCMOUNTDARGS'] => String,
  Optional['RPCNFSDARGS']   => String,
  Optional['GSSDARGS']      => String,
  Optional['SMNOTIFYARGS']  => String,
  Optional['STATDARGS']     => String
}]

