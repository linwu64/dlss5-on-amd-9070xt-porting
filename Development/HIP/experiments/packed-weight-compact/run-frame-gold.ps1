$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\packed-weight-compact-20261012'
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
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$base\modules-current\deep_fast-packed-fast.hsaco")){if(!(Test-Path $p)){throw "required asset $p"}}
if((Get-Item "$base\input.f16").Length -ne 7464960 -or (Get-FileHash "$base\input.f16").Hash -ne 'fa3c18735ac5f105903614a18a9b1475966b9afd9dd4aeb0cd9cad7bc759ec9b'){throw 'HDR actual1296x720x8 SHA'}
if((Get-FileHash "$base\modules-current\deep_fast-packed-fast.hsaco").Hash -ne '11a25ae3fea75f83763ab6d5729c4f426dabda11299d1be6092d142b810e27b8'){throw 'canonical expand module'}
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
Get-ChildItem "$base\modules-current" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-preflight.json"
Get-FileHash "$base\input.f16","$base\base.flags","$case\same.flags","$base\assets-common\noise.f32"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$case\source-preflight.json"
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 foreach($name in 'baseline','compact'){
  Idle
  $d=New-Item -ItemType Directory "$case\$name"
  New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force|Out-Null
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
  Copy-Item "$r\frame-$name.exe" "$d\frame.exe"
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$d\frame.exe";$psi.WorkingDirectory=$d.FullName
  $psi.Arguments="`"$base\assets-common`" `"$case\same.flags`" `"$base\input.f16`" `"$d\out`" 3 0 `"$base\modules-current`" 0 0 0 0"
  $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
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
  if($mem -notmatch 'processing=1920x1152' -or $mem -notmatch 'hip_memory_exact weights_bytes='){throw 'actualgeometry memory exact receipt missing'}
  Get-FileHash "$d\out-first.f16","$d\out.f16"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$d\raw-sha.json"
 }
 $ref=(Get-FileHash "$case\baseline\out-first.f16").Hash
 foreach($f in @("$case\baseline\out.f16","$case\compact\out-first.f16","$case\compact\out.f16")){if((Get-FileHash $f).Hash -ne $ref){throw 'cross same HDR raw failed'}}
 $c=Get-Content "$case\compact\stderr.log" -Raw
 if(([regex]::Matches($c,'COMPACT_WEIGHT key=')).Count -ne 8 -or $c -match 'COMPACT_WEIGHT[^\r\n]*legacy_key_present=[1-9]' -or $c -notmatch 'allocation_capacity=4194304'){throw 'actual8compact allocations gate'}
 'FRAME_RAW_REPEAT_FINITE_PASS_NOT_PERFORMANCE'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
