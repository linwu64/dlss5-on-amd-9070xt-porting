$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-042'
$llvm=Get-Content "$r\llvm-manifest.json" -Raw|ConvertFrom-Json
$all=@()
foreach($arch in 'gfx1200','gfx1201'){
 $m=Get-Content "$r\HIP\$arch\modules.json" -Raw|ConvertFrom-Json
 foreach($x in $llvm.modules|Where-Object{$_.target -eq $arch}){
  $src="$r\prebuilt\$arch\$($x.module).hsaco";$dest="$r\HIP\$arch\$($x.module).hsaco"
  if((Get-FileHash $src).Hash -ne $x.sha256){throw 'LLVM sourcebinary manifest'}
  Copy-Item $src $dest
  $m+=@{target=$arch;module=$x.module;sha256=$x.sha256;source_sha256=$x.source_sha256;compiler='LLVM23 exactCPU receipt';defines=$x.defines;commands=$x.commands}
 }
 if($m.Count -ne 40 -or @(Get-ChildItem "$r\HIP\$arch" -Filter '*.hsaco').Count -ne 40){throw 'official40'}
 $m|ConvertTo-Json -Depth 8|Set-Content "$r\HIP\$arch\modules.json"
 foreach($x in $m){$f="$r\HIP\$arch\$($x.module).hsaco";if((Get-FileHash $f).Hash -ne $x.sha256){throw 'identity'};$all+=((Get-FileHash $f).Hash.ToLower()+'  '+$arch+'/'+$x.module+'.hsaco')}
}
[IO.File]::WriteAllLines("$r\HIP-SHA256SUMS",$all,[Text.UTF8Encoding]::new($false))
New-Item -ItemType Directory "$r\modules-candidate"|Out-Null
Copy-Item "$r\HIP\gfx1201\*.hsaco" "$r\modules-candidate"
New-Item -ItemType Directory "$r\modules-baseline"|Out-Null
Copy-Item 'D:\DLSSNR-Lab\vit-tail-production-final-20261012\modules-candidate\*.hsaco' "$r\modules-baseline"
Copy-Item 'D:\DLSSNR-Lab\vit-tail-production-final-20261012\frame.exe' "$r\frame.exe"
if((Get-FileHash "$r\frame.exe").Hash -ne '1a31a3ecb3e120ca6a96f9b118e8625e9b1e339cfebe3f56733bbe6231e5df69'){throw 'existinggoldcaller identity'}
'OFFICIAL80_MERGED_NO_DEVICE'
