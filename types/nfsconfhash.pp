# Hash representing nfs.conf configuration
type Nfs::NfsConfHash = Struct[{
  Optional['general']     => Hash[String,Variant[Boolean,Integer,Float,String]],
  Optional['exportfs']    => Hash[String,Variant[String,Number,Boolean]],
  Optional['gssd']        => Hash[String,Variant[String,Number,Boolean]],
  Optional['lockd']       => Hash[String,Variant[String,Number,Boolean]],
  Optional['mountd']      => Hash[String,Variant[String,Number,Boolean]],
  Optional['nfsd']        => Hash[String,Variant[String,Number,Boolean]],
  Optional['nfsdcltrack'] => Hash[String,Variant[String,Number,Boolean]],
  Optional['sm-notify']   => Hash[String,Variant[String,Number,Boolean]],
  Optional['statd']       => Hash[String,Variant[String,Number,Boolean]]
}]

