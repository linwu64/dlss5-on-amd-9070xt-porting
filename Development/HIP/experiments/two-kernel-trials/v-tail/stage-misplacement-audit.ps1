$ErrorActionPreference='Stop'
@(foreach($name in 'build.ps1','candidate.hip','source.json'){
 $p="D:\DLSSNR-Lab\$name";$f=Get-Item $p
 [pscustomobject]@{path=$p;creation_utc=$f.CreationTimeUtc.ToString('o');last_write_utc=$f.LastWriteTimeUtc.ToString('o');bytes=$f.Length;sha256=(Get-FileHash $p).Hash}
})|ConvertTo-Json
