$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-042';$llvm=Get-Content "$r\llvm-manifest.json" -Raw|ConvertFrom-Json
$all=@();foreach($arch in 'gfx1200','gfx1201'){
 $m=Get-Content "$r\HIP\$arch\modules.json" -Raw|ConvertFrom-Json
 foreach($x in $m){$g="$r\HIP\$arch\$($x.module).generated.hip";$l=@($llvm.modules|Where-Object{$_.target -eq $arch -and $_.module -eq $x.module});$all+=@{target=$arch;module=$x.module;sha256=(Get-FileHash "$r\HIP\$arch\$($x.module).hsaco").Hash.ToLower();source_sha256=$(if($l.Count){$l[0].source_sha256}else{(Get-FileHash $g).Hash.ToLower()});defines=$x.defines;opts=$x.opts;route=$(if($l.Count){'LLVM23 CPU exact source receipt'}else{'driver COMGR official recipe'});llvm_commands=$(if($l.Count){$l[0].commands}else{$null})}}
}
if($all.Count -ne 80){throw '80'}
@{source_zip_sha256=(Get-FileHash "$r\source.zip").Hash.ToLower();compiler_comgr_exe_sha256=(Get-FileHash 'D:\DLSSNR-Lab\build-0927\rtc_compile.exe').Hash.ToLower();source_commit='456b7e16';modules=$all}|ConvertTo-Json -Depth 10|Set-Content "$r\final-module-manifest.json"
'FINAL_SOURCE_MANIFEST80'
