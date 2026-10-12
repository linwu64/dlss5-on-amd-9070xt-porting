$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-contract-compact-frame-20261012'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\frame-manifest.json" -Raw|ConvertFrom-Json
foreach($f in $m.files){$p=Join-Path $r $f.file;if((Get-Item $p).Length -ne $f.bytes -or (Get-FileHash $p).Hash -ne $f.sha256){throw "identity $($f.file)"}}
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$r\modules\deep_fast-packed-fast.hsaco")){if(!(Test-Path $p)){throw "required asset $p"}}
if((Get-Item "$base\input.f16").Length -ne 7464960 -or (Get-FileHash "$base\input.f16").Hash -ne 'fa3c18735ac5f105903614a18a9b1475966b9afd9dd4aeb0cd9cad7bc759ec9b'){throw 'HDR actual1296x720x8 SHA'}
if((Get-FileHash "$r\modules\deep_fast-packed-fast.hsaco").Hash -ne '11a25ae3fea75f83763ab6d5729c4f426dabda11299d1be6092d142b810e27b8'){throw 'canonical expand module'}
if(Test-Path "$r\frame-gold"){throw 'existing case no retry'}
$case=New-Item -ItemType Directory "$r\frame-gold"
$flags=Get-Content "$base\base.flags" -Raw
$fixed=@'
DLSS5_NETWORK_HEIGHT=1080
DLSS5_NETWORK_1080_ROWS=1152
DLSS5_NETWORK_FREE_RES=0
DLSS5_STYLE=1
DLSS5_HIP_PDL=1
DLSS5_HIP_SUBMIT_PULSE=auto
DLSS5_HIP_GRAPH=0
DLSS5_FAST_NUMERIC=1
DLSS5_VIT_ADAPTIVE=0
DLSS5_MULTI_PASS=1
DLSS5_MULTI_PASS_PREDICT=0
DLSS5_MULTI_PASS_SKIN_PROTECT=0
DLSS5_MULTI_PASS_HOTKEY=none
DLSS5_HOT_RELOAD=0
DLSS5_TEMPORAL_MODE=0
DLSS5_FAST_HISTORY=0
DLSS5_TEMPORAL_HISTORY_EXPERIMENT=0
DLSS5_TEST_SUBMISSION_TIMING=0
DLSS5_HIP_MEMORY=1
DLSS5_BENCH_PLAIN=1
DLSS5_FRAME_STATS=0
DLSS5_RESIDUAL_SEQUENCE=0
DLSS5_RESIDUAL_RGB=0
DLSS5_SKIP_BLOCKS=
'@
$flags+="`r`n"+$fixed+"`r`n"
$flags|Set-Content "$case\same.flags"
Get-ChildItem "$r\modules" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-preflight.json"
Get-FileHash "$base\input.f16","$base\base.flags","$case\same.flags","$base\assets-common\noise.f32"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$case\source-preflight.json"
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 foreach($name in 'baseline','candidate'){
  Idle
  $d=New-Item -ItemType Directory "$case\$name"
  New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force|Out-Null
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
  Copy-Item "$r\frame.exe" "$d\frame.exe"
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$d\frame.exe";$psi.WorkingDirectory=$d.FullName
  $psi.Arguments="`"$base\assets-common`" `"$case\same.flags`" `"$base\input.f16`" `"$d\out`" 3 0 `"$r\modules`" 0 0 0 0"
  $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
  $psi.EnvironmentVariables['NR_VIT_CONTRACT_COMPACT']=if($name -eq 'candidate'){'1'}else{'0'}
  $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
  "CASE=frame-gold ROLE=$name OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
  try {
   while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 90){throw 'own90s timeout no retry'}}
   $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode) ROLE=$name";if($p.ExitCode){throw "frame failed $name $($p.ExitCode)"}
  } finally {
   if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
   $o.Result|Set-Content "$d\stdout.log";$e.Result|Set-Content "$d\stderr.log"
  }
  $rows=@(Import-Csv "$d\out.csv");if($rows.Count -ne 3 -or @($rows|Where-Object {[int]$_.invalid -ne 0 -or [int]$_.changed_half_values_from_first -ne 0}).Count){throw 'three actualfinite repeat frames'}
  $log=Get-Content "$d\stderr.log" -Raw
  if($log -notmatch 'submit_pulse resources[^\r\n]*record_ok=3[^\r\n]*accepted=3'){throw 'actualproductionAuto three records required'}
  if(!(Test-Path "$d\DLSS5-AMD\logs\native-hip.txt")){throw 'memory source log missing'}
  $mem=Get-Content "$d\DLSS5-AMD\logs\native-hip.txt" -Raw
  if($mem -notmatch 'processing=1920x1152' -or $mem -notmatch 'hip_memory '){throw 'actualgeometry memory exact receipt missing'}
  Get-FileHash "$d\out-first.f16","$d\out.f16"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$d\raw-sha.json"
 }
 $ref=(Get-FileHash "$case\baseline\out-first.f16").Hash
 foreach($f in @("$case\baseline\out.f16","$case\candidate\out-first.f16","$case\candidate\out.f16")){if((Get-FileHash $f).Hash -ne $ref){throw 'cross same HDR raw failed'}}
 $c=Get-Content "$case\candidate\stderr.log" -Raw
 if($c -notmatch 'submit_pulse resources[^\r\n]*record_ok=3[^\r\n]*accepted=3'){throw 'candidate Auto3'}
 $cm=Get-Content "$case\candidate\DLSS5-AMD\logs\native-hip.txt" -Raw
 if($cm -notmatch 'hip_bridge_resources never_history=1 input_bytes=35389440 history_bytes=0 output_bytes=26542080'){throw 'candidate keepsstage1'}
 $bm=Get-Content "$case\baseline\DLSS5-AMD\logs\native-hip.txt" -Raw
 $clog=Get-Content "$case\candidate\stderr.log" -Raw;$blog=Get-Content "$case\baseline\stderr.log" -Raw
 if($clog -notmatch 'CONTRACT_COMPACT_COLD requested=1 ready=1' -or ([regex]::Matches($clog,'CONTRACT_COMPACT key=')).Count -ne 8 -or $clog -match 'CONTRACT_COMPACT key=[^\r\n]*legacy_held=[1-9]'){throw 'candidate8compactkeys/nolegacy pairedroute'}
 if($blog -notmatch 'CONTRACT_COMPACT_COLD requested=0 ready=0' -or $blog -match 'CONTRACT_COMPACT key='){throw 'baselinecompactfalse'}
 if($bm -notmatch 'hip_memory_exact weights_bytes=423438120 ' -or $cm -notmatch 'hip_memory_exact weights_bytes=322774824 '){throw 'actualcompleteFrame96MiBweights capacity'}
 if($ref -ne '0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a'){throw 'accepted completeFramegold SHA'}
 Get-ChildItem "$r\modules" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-after.json"
 $before=Get-Content "$case\modules-preflight.json" -Raw|ConvertFrom-Json;$after=Get-Content "$case\modules-after.json" -Raw|ConvertFrom-Json
 if($before.Count -ne $after.Count){throw 'modulecount changed'}
 foreach($x in $before){$y=@($after|Where-Object {$_.file -eq $x.file});if($y.Count -ne 1 -or $y[0].bytes -ne $x.bytes -or $y[0].sha256 -ne $x.sha256){throw 'module identity changed'}}
 'FRAME_RAW_REPEAT_FINITE_PASS_CONTRACT_COMPACT_NOT_PERFORMANCE' 
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
