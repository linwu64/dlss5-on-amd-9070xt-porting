$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$r='D:\DLSSNR-Lab\release-044-f9fix';$out='D:\給網友打包'
$z=[IO.Compression.ZipFile]::OpenRead("$out\OptiScaler-REFramework-DLSS5-AMD-0.44.zip")
try{
 $e=@($z.Entries|Where-Object {$_.FullName.Replace('\','/') -eq 'sources/re9-presr-source.tar.gz'})
 if($e.Count -ne 1){throw 'source archive entry'}
 $s=$e[0].Open();$h=[Security.Cryptography.SHA256]::Create()
 try{$got=([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToLower()}finally{$s.Dispose();$h.Dispose()}
 $expected=(Get-FileHash "$r\re9-presr-source.tar.gz").Hash.ToLower();if($got -ne $expected){throw 'source archive mismatch'}
 [pscustomobject]@{source_archive_sha256=$got;verified=$true}|ConvertTo-Json|Set-Content "$r\zip-source-verified.json"
}finally{$z.Dispose()}
foreach($prefix in 'Magpie-DLSS5-AMD','OptiScaler-DLSS5-AMD','OptiScaler-REFramework-DLSS5-AMD'){
 $file="$out\$prefix-0.44.zip";$sha=(Get-FileHash $file).Hash.ToLower();$side=((Get-Content "$file.sha256" -Raw).Trim() -split '\s+')[0];if($sha -ne $side){throw 'sidecar mismatch'}
}
'SOURCE_ARCHIVE_AND_ALL3_SIDECARS_PASS'
