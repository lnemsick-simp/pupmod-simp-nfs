# Hash representing nfs.conf configuration
type Nfs::NfsConfHash = Struct[{
  Optional['general']     => Hash,
  Optional['exportfs']    => Hash,
  Optional['gssd']        => Hash,
  Optional['lockd']       => Hash,
  Optional['mountd']      => Hash,
  Optional['nfsd']        => Hash,
  Optional['nfsdcltrack'] => Hash,
  Optional['sm-notify']   => Hash,
  Optional['statd']       => Hash
}]

